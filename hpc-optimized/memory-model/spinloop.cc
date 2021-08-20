#include <atomic>
#include <thread>
#include <iostream>
#include <iomanip>
using namespace std;

unsigned long state = 0;
unsigned int iterations = 1000000;
std::atomic<bool> lock{false};
std::atomic<bool> go;
int global;

#define likely(x)       __builtin_expect(((x) != 0),1)
#define unlikely(x)     __builtin_expect(((x) != 0),0)

void lock_func()
{
  global = 0;
  bool expected = false;
#ifdef OPTIMIZED
  while (unlikely(!lock.compare_exchange_strong(expected, true, std::memory_order_acquire)));
#else
  while (unlikely(!lock.compare_exchange_strong(expected, true)));
#endif
}

void unlock_func()
{
#ifdef OPTIMIZED
  lock.store(false, std::memory_order_release);
#else
  lock.store(false);
#endif
}

void workload_execute()
{
  while (!go);
  for (unsigned int i = 0; i < iterations; ++i) {
    lock_func();
    state = (rand() * i) % 1000;
    unlock_func();
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

  go = false;
  for (size_t i = 0; i < num_of_threads; ++i) {
    handles[i] = new std::thread(workload_execute);
  }
  go = true;

  for (size_t i = 0; i < num_of_threads; ++i) {
    handles[i]->join();
  }

  auto finish = std::chrono::high_resolution_clock::now();

  for (size_t i = 0; i < num_of_threads; ++i) {
    delete handles[i];
  }

  std::chrono::duration<double> elapsed = finish - start;
  std::cout << "Elapsed time: " << elapsed.count() << " s\n";
  std::cout << "-----------------------" << "\n";
}

