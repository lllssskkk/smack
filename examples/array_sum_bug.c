#include <stdlib.h>
#include "smack.h"

unsigned array_sum(const unsigned *a, unsigned n) {
  unsigned sum = 0;
  for (unsigned i = 0; i <= n; i++)
    sum += a[i];
  return sum;
}

int main(void) {
  unsigned n = __VERIFIER_nondet_unsigned();   // any length ...
  __VERIFIER_assume(1 <= n && n <= 4);         // ... from 1 to 4, for a bounded check
  unsigned *a = malloc(n * sizeof(unsigned));
  if (!a) return 0;
  array_sum(a, n);
  free(a);
  return 0;
}
