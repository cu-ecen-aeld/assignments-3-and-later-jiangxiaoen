#include "threading.h"
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>

// Optional: use these functions to add debug or error prints to your application
#define DEBUG_LOG(msg,...)
//#define DEBUG_LOG(msg,...) printf("threading: " msg "\n" , ##__VA_ARGS__)
#define ERROR_LOG(msg,...) printf("threading ERROR: " msg "\n" , ##__VA_ARGS__)

int shared_counter=0;

void* threadfunc(void* thread_param)
{
    struct thread_data *data = (struct thread_data *) thread_param;

    if (data->wait_to_obtain_ms > 0)
        usleep(data->wait_to_obtain_ms * 1000);

    pthread_mutex_lock(data->mutex);

    if (data->wait_to_release_ms > 0)
        usleep(data->wait_to_release_ms * 1000);

    shared_counter++;
    printf("Thread %ld: counter = %d\n", pthread_self(), shared_counter);

    pthread_mutex_unlock(data->mutex);

    data->thread_complete_success = true;
    return data;
}


bool start_thread_obtaining_mutex(pthread_t *thread, pthread_mutex_t *mutex,
                                  int wait_to_obtain_ms, int wait_to_release_ms)
{
    // Allocate memory for thread data
    struct thread_data *data = malloc(sizeof(struct thread_data));
    if (data == NULL) {
        ERROR_LOG("malloc failed");
        return false;
    }

    // Initialise the structure
    data->mutex = mutex;
    data->wait_to_obtain_ms = wait_to_obtain_ms;
    data->wait_to_release_ms = wait_to_release_ms;
    data->thread_complete_success = false;

    // Create the thread
    if (pthread_create(thread, NULL, threadfunc, data) != 0) {
        ERROR_LOG("pthread_create failed");
        free(data);
        return false;
    }

    return true;
}

/*#define NUM_THREADS 10

int main()
{
    pthread_t threads[NUM_THREADS];
    pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
    shared_counter = 0;   // reset global counter

    for (int i = 0; i < NUM_THREADS; i++) {
        if (!start_thread_obtaining_mutex(&threads[i], &mutex, 0, 0)) {
            ERROR_LOG("Failed to start thread %d", i);
            return 1;
        }
    }

    for (int i = 0; i < NUM_THREADS; i++) {
        void *res;
        pthread_join(threads[i], &res);
        struct thread_data *data = (struct thread_data *)res;
        if (data && !data->thread_complete_success)
            ERROR_LOG("Thread %d did not complete successfully", i);
        free(data);
    }

    printf("Final shared_counter = %d (expected %d)\n", shared_counter, NUM_THREADS);
    return 0;
}*/
