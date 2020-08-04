#include <atomic>
#include <iostream>
using namespace std;
#include <arm_acle.h>
#include <thread>
#include <chrono>
#include <zlib.h>
#include <string.h>

#define likely(x)       __builtin_expect((x),1)
#define unlikely(x)     __builtin_expect((x),0)

const size_t data_block_size = 64*1024;
char data_block[64*1024];

size_t k_iter=100;
unsigned long global_crcval = 0;

/* ---------------- spin-lock ---------------- */
std::atomic<bool> lock_unit{0};
void lock()
{
  while (true) {
    bool expected = false;
    if (unlikely(!lock_unit.compare_exchange_strong(expected, true))) {
      __asm__ __volatile__("" ::: "memory");
      continue;
    }
    break;
  }
}

void unlock()
{
  lock_unit.store(false);
}

/* ---------------- workload ---------------- */
void workload_execute()
{
  for (size_t i = 0; i < k_iter; ++i) {
    lock();
    /* Each thread try to take lock -> execute critical section -> unlock */
    memset(data_block, rand() % 255, data_block_size);
    unsigned long crcval = 0;
    crc32(crcval, (const unsigned char *)data_block, data_block_size);
    unlock();
    global_crcval += crcval;
  }
}

int main(int argc, char *argv[]) {
  if (argc != 2) {
    cerr << "usage: <program> <number-of-threads/parallelism>" << endl;
    return 1;
  }
  size_t num_of_threads = atol(argv[1]);

  std::thread* handles[num_of_threads];

  auto start = std::chrono::high_resolution_clock::now();

  for (size_t i = 0; i < num_of_threads; ++i) {
    handles[i] = new std::thread(workload_execute);
  }
  for (size_t i = 0; i < num_of_threads; ++i) {
    handles[i]->join();
  }

  auto finish = std::chrono::high_resolution_clock::now();

  for (size_t i = 0; i < num_of_threads; ++i) {
    delete handles[i];
  }

  std::chrono::duration<double> elapsed = finish - start;
  std::cout << "Elapsed time: " << elapsed.count() << " s\n";
}
