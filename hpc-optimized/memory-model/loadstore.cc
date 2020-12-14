#include <atomic>
#include <thread>
#include <iostream>
using namespace std;

int global;

std::atomic<int> x{0};
void load() {
  global = 0;
  int e{0};
#ifdef OPTIMIZED
  x.compare_exchange_strong(e, false, std::memory_order_acquire);
#else
  x.compare_exchange_strong(e, false);
#endif
}

void store() {
  global = 0;
#ifdef OPTIMIZED
  x.store(false, std::memory_order_release);
#else
  x.store(false);
#endif
}

void workload_execute()
{
  for (int i = 0; i < 1000000; ++i) {
    load();
    store();
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
