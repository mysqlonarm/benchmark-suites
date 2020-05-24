
#include <atomic>
#include <chrono>
#include <cstdlib>
#include <iostream>
#include <math.h>
#include <mutex>
#include <string.h>
#include <thread>
#include <unistd.h>
#include <vector>
#include <zlib.h>

#include <numa.h>
#include <numaif.h>

/* round amplifier is adjusted to ensure that L2 cache is invalidated
on each data-processing round. So say k_round_amplifier = 4 and each
data-processing round is touching 4 blocks so each round of data-processing
will touch 4 * 4 = 16 data-block of 16 KB each that is 256K */
const uint32_t k_round_amplifier = 16;

const uint32_t k_num_of_counter_per_counter_block = 10;
const size_t k_data_size = (16 * 1024);
const size_t k_cores = 24;

#if defined(__x86_64__)
const size_t k_cacheline_size = 64;
#elif defined(__aarch64__)
const size_t k_cacheline_size = 128;
#endif

uint64_t my_timer_cycles(void) {
#if defined(__GNUC__) && defined(__x86_64__)
  {
    uint64_t result;
    __asm__ __volatile__("rdtsc\n\t"
                         "shlq $32,%%rdx\n\t"
                         "orq %%rdx,%%rax"
                         : "=a"(result)::"%edx");
    return result;
  }
#elif defined(__GNUC__) && defined(__aarch64__)
  {
    uint64_t result;
    __asm __volatile__("mrs %[rt],cntvct_el0" : [ rt ] "=r"(result));
    return result;
  }
#else
  return 0;
#endif
}

template <size_t N = k_cores> struct counter_indexer_t {
  static size_t get_rnd_index() {
    return (static_cast<size_t>(my_timer_cycles()));
  }

  static size_t offset(size_t index) {
    return (((index % N) + 1) * (k_cacheline_size / sizeof(uint64_t)));
  }
};

template <size_t N = k_cores> class Counter {
public:
  Counter() { memset(m_counter, 0x0, sizeof(m_counter)); }

  void inc() { inc(1); }
  void dec() { dec(1); }

  void inc(uint64_t incr) {
    size_t idx = m_indexer.offset(m_indexer.get_rnd_index());
    m_counter[idx] += incr;
  }

  void dec(uint64_t decr) {
    size_t idx = m_indexer.offset(m_indexer.get_rnd_index());
    m_counter[idx] -= decr;
  }

  const uint64_t get() {
    uint64_t total = 0;
    for (size_t i = 0; i < N; ++i) {
      total += m_counter[m_indexer.offset(i)];
    }
    return (total);
  }

  void set(uint64_t val) {
    reset();
    size_t idx = m_indexer.offset(m_indexer.get_rnd_index());
    m_counter[idx] = val;
  }

  void reset() { memset(m_counter, 0x0, sizeof(m_counter)); }

private:
  counter_indexer_t<N> m_indexer;

  uint64_t m_counter[(N + 1) * (k_cacheline_size / sizeof(uint64_t))];
};

/* Each block has N counters and flow has M such blocks. */
class CounterBlock {
public:
  CounterBlock(size_t num_of_counters) : m_num_of_counters(num_of_counters) {
    m_values = new Counter<k_cores> *[m_num_of_counters];
    for (uint32_t i = 0; i < m_num_of_counters; ++i) {
      m_values[i] = new Counter<k_cores>();
    }
  }

  ~CounterBlock() {
    for (uint32_t i = 0; i < m_num_of_counters; ++i) {
      delete m_values[i];
    }
    delete[] m_values;
    m_values = 0;
  }

  void set(uint32_t idx, uint64_t value) { m_values[idx]->set(value); }
  uint64_t get(uint32_t idx) { return (m_values[idx]->get()); }

  void inc(uint32_t idx) { m_values[idx]->inc(); }
  void dec(uint32_t idx) { m_values[idx]->dec(); }
  void inc(uint32_t idx, uint64_t incr) { m_values[idx]->inc(incr); }
  void dec(uint32_t idx, uint64_t decr) { m_values[idx]->dec(decr); }

  size_t count() { return m_num_of_counters; }

#ifdef DEBUG
  /* debug only */
  void print() {
    for (uint32_t i = 0; i < m_num_of_counters; ++i) {
      std::cout << m_values[i]->get() << ", ";
    }
    std::cout << std::endl;
  }
#endif /* DEBUG */

  uint64_t total() {
    uint64_t total = 0;
    for (uint32_t i = 0; i < m_num_of_counters; ++i) {
      total += m_values[i]->get();
    }
    return total;
  }

  void reset() {
    for (uint32_t i = 0; i < m_num_of_counters; ++i) {
      m_values[i]->set(0);
    }
  }

private:
  /* don't use vector to help control how the counter array is allocated */
  Counter<k_cores> **m_values;
  size_t m_num_of_counters;
};

/* There are P data blocks */
class DataBlock {
public:
  DataBlock() : m_value(), m_data() {
    memset(m_data, rand() % 255, k_data_size);
  }

  void inc() { m_value.inc(); }
  void dec() { m_value.dec(); }
  void inc(uint64_t incr) { m_value.inc(incr); }
  void dec(uint64_t decr) { m_value.dec(decr); }

  /* Note: class not meant for isolation but to faciliate
  allocation so allowing exposing private data. */
  char *data() { return m_data; }

  uint64_t total() { return m_value.get(); }
  void reset() { m_value.set(0); }

private:
  Counter<k_cores> m_value;
  char m_data[k_data_size];
};

/* Pay allocate counter blocks and data blocks. */
class PayLoad {
public:
  PayLoad(size_t num_of_counters, size_t num_of_counter_blocks,
          size_t num_of_data_blocks)
      : m_counter_blocks(num_of_counter_blocks),
        m_data_blocks(num_of_data_blocks) {

    uint32_t data_block_allocated = 0;
    uint32_t data_block_allocation_size =
        (num_of_data_blocks / num_of_counter_blocks);

    for (size_t i = 0; i < m_counter_blocks.size(); ++i) {

      m_counter_blocks[i] = new CounterBlock(num_of_counters);

      for (size_t j = 0; j < data_block_allocation_size; ++j) {
        m_data_blocks[data_block_allocated] = new DataBlock();
        data_block_allocated++;
      }
    }

    /* allocate pending data-blocks (if any) */
    for (size_t i = data_block_allocated; i < m_data_blocks.size(); ++i) {
      m_data_blocks[data_block_allocated] = new DataBlock();
      data_block_allocated++;
    }
  }

  void process_counter_block() {
    uint32_t counter_block = rand() % m_counter_blocks.size();
    CounterBlock *block = m_counter_blocks[counter_block];
    uint32_t counter_idx = rand() % block->count();
    block->inc(counter_idx);
  }

  void process_data_block() {
    uint32_t data_block1 = rand() % m_data_blocks.size();
    uint32_t data_block2 = rand() % m_data_blocks.size();
    uint32_t data_block3 = rand() % m_data_blocks.size();
    uint32_t data_block4 = rand() % m_data_blocks.size();

    size_t offset1 = rand() % (k_data_size / 10);
    size_t offset2 = rand() % (k_data_size / 10);
    size_t offset3 = rand() % (k_data_size / 2);

    /* read write unaligned access */
    memcpy(m_data_blocks[data_block1]->data() + offset1,
           m_data_blocks[data_block2]->data() + offset2, offset3);
    m_data_blocks[data_block1]->inc();
    m_data_blocks[data_block2]->inc();

    /* write align access */
    memset(m_data_blocks[data_block3]->data(), rand() % 255, k_data_size);
    m_data_blocks[data_block3]->inc();

    /* read unaligned access */
    memcmp(m_data_blocks[data_block3] + offset1,
           m_data_blocks[data_block2] + offset2, offset3);
    m_data_blocks[data_block3]->inc();
    m_data_blocks[data_block2]->inc();

    /* CPU bound */
    unsigned long crcval = 0;
    crc32(crcval, (const unsigned char *)m_data_blocks[data_block4]->data(),
          k_data_size);
    m_data_blocks[data_block4]->inc();

    /* add whatever code you feel can generate load on cpu or
    stimulate your program behavior in minimalist way. */
  }

  ~PayLoad() {
    for (size_t i = 0; i < m_data_blocks.size(); ++i) {
      delete m_data_blocks[i];
    }
    m_data_blocks.clear();

    for (size_t i = 0; i < m_counter_blocks.size(); ++i) {
      delete m_counter_blocks[i];
    }
    m_counter_blocks.clear();
  }

#ifdef DEBUG
  /* Debug only */
  void print() {
    for (size_t i = 0; i < m_counter_blocks.size(); ++i) {
      std::cout << "CounterBlock " << (i + 1) << std::endl;
      m_counter_blocks[i]->print();
    }
    std::cout << "-----------------------------------------" << std::endl;
  }
#endif /* DEBUG */

  uint64_t ctotal() {
    uint64_t total = 0;
    for (size_t i = 0; i < m_counter_blocks.size(); ++i) {
      total += m_counter_blocks[i]->total();
    }
    return total;
  }

  uint64_t dtotal() {
    uint64_t total = 0;
    for (uint32_t i = 0; i < m_data_blocks.size(); ++i) {
      total += m_data_blocks[i]->total();
    }
    return total;
  }

  void reset() {
    for (size_t i = 0; i < m_counter_blocks.size(); ++i) {
      m_counter_blocks[i]->reset();
    }
    for (uint32_t i = 0; i < m_data_blocks.size(); ++i) {
      m_data_blocks[i]->reset();
    }
  }

public:
  std::vector<CounterBlock *> m_counter_blocks;

  std::vector<DataBlock *> m_data_blocks;
};

class Workload {
public:
  static void execute(size_t idx, PayLoad *data, uint32_t rounds) {
    // std::cout << "Inside workload for thread " << idx << std::endl;

    /* Each round
    - Executes k_rounds of data-processing
    - For each round of data-processing (that in turn touches 4 blocks)
      X global counters are updated.
    */
    for (uint32_t i = 0; i < rounds; ++i) {
      for (uint32_t j = 0; j < k_round_amplifier; ++j) {
        data->process_data_block();
      }
      for (uint32_t j = 0;
           j < (k_num_of_counter_per_counter_block * k_round_amplifier); ++j) {
        data->process_counter_block();
      }
    }
  }
};

int main(int argc, char *argv[]) {
  if (argc < 5 || argc > 6) {
    std::cerr << "Usage: ./<program> <num-of-threads> <num-of-counter-blocks> "
                 "<num-of-data-blocks> <rounds> [numa]"
              << std::endl;
    return 1;
  }

  size_t num_of_threads = atol(argv[1]);
  size_t num_of_counter_blocks = atol(argv[2]);
  size_t num_of_data_blocks = atol(argv[3]);
  uint32_t rounds = atol(argv[4]);
  bool numa = (strcmp(argv[5] ? argv[5] : "", "numa") == 0);

  if (numa && set_mempolicy(MPOL_INTERLEAVE, numa_all_nodes_ptr->maskp,
                            numa_all_nodes_ptr->size) != 0) {
    std::cerr << "Fail to honor NUMA policy (INTERLEAVE)" << std::endl;
    return 1;
  }

  PayLoad *data = new PayLoad(k_num_of_counter_per_counter_block,
                              num_of_counter_blocks, num_of_data_blocks);

  if (numa && set_mempolicy(MPOL_DEFAULT, nullptr, 0) != 0) {
    std::cerr << "Fail to honor NUMA policy (DEFAULT)" << std::endl;
    return 1;
  }

  for (uint32_t thrd = 1; thrd <= num_of_threads; thrd *= 2) {

    std::cout << "Running workload with " << thrd << " scalability"
              << std::endl;

    std::thread *handles[thrd];

    auto start = std::chrono::high_resolution_clock::now();

    for (size_t i = 0; i < thrd; ++i) {
      handles[i] = new std::thread(Workload::execute, i, data, rounds);
    }
    for (size_t i = 0; i < thrd; ++i) {
      handles[i]->join();
    }

    auto finish = std::chrono::high_resolution_clock::now();

    for (size_t i = 0; i < thrd; ++i) {
      delete handles[i];
    }

    std::cout << "Global Counter Total: " << data->ctotal() << std::endl;
    std::cout << "Data Counter Total: " << data->dtotal() << std::endl;
    std::chrono::duration<double> elapsed = finish - start;
    std::cout << "Elapsed time: " << elapsed.count() << " s\n";
    std::cout << "--------------------------" << std::endl;

    data->reset();
  }

  delete data;
  return 0;
}

