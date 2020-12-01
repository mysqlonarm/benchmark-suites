#include <atomic>
#include <thread>
#include <iostream>
using namespace std;

std::atomic<int> x{0};
int global;

int one_action()
{
     global = 0;
#ifdef EXCHANGE
     x.exchange(true);
#endif
#ifdef LOAD
     x.load();
#endif
#ifdef STORE
     x.store(true);
#endif
#ifdef FENCE
     std::atomic_thread_fence(std::memory_order_acquire);
#endif
#ifdef BAD_CAS
     int e{1};
     x.compare_exchange_strong(e,false, std::memory_order_acq_rel);
#endif
#ifdef OK_CAS
     int e{0};
     x.compare_exchange_strong(e,false, std::memory_order_acq_rel);
#endif
#ifdef FETCH_OR
     x.fetch_or(0);
#endif
#ifdef FETCH_ADD
     x.fetch_add(1);
#endif
  return 0;
}

int workload_execute()
{
   for(int i=0;i<1000000;++i){
     one_action();
   }
   return 0;
}

int main(int argc, char *argv[]) {
  if (argc != 2) {
    cerr << "usage: <program> <number-of-threads/parallelism>" << endl;
    return 1;
  }
  size_t num_of_threads = atol(argv[1]);

  std::thread* handles[num_of_threads];

  // auto start = std::chrono::high_resolution_clock::now();

  for (size_t i = 0; i < num_of_threads; ++i) {
    handles[i] = new std::thread(workload_execute);
  }
  for (size_t i = 0; i < num_of_threads; ++i) {
    handles[i]->join();
  }

  // auto finish = std::chrono::high_resolution_clock::now();

  for (size_t i = 0; i < num_of_threads; ++i) {
    delete handles[i];
  }

  //std::chrono::duration<double> elapsed = finish - start;
  //std::cout << "Elapsed time: " << elapsed.count() << " s\n";
}

