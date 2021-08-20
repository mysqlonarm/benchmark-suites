#include <atomic>
#include <thread>
#include <iostream>
#include <iomanip>
using namespace std;

std::atomic<bool> go{false};
std::atomic<unsigned long> ops{0};
int global;

void incr() {
  // ensure all store is done before core may proceed.
  global = 0;
#ifdef OPTIMIZED
  ops.fetch_add(1, std::memory_order_relaxed);
#else
  ops.fetch_add(1);
#endif
}

void workload_execute()
{
  while (!go);
  for (int i = 0; i < 1000000; ++i) {
    incr();
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
  std::cout << "ops: " << ops.load() << "\n";
  std::cout << "ops/sec: " << std::setprecision (15) << ops.load() / elapsed.count() << "\n";
  std::cout << "-----------------------" << "\n";
}

