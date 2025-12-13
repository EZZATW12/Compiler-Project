#include <stdio.h>
#include <stdlib.h>

int main() {
    int x = 5;
    int y;
    int z;
    (y = (z = x));
    printf("%d\n", y);
    printf("%d\n", z);
    return 0;
}
