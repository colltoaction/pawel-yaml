#include <stdio.h>
#include <string.h>
#include <assert.h>
#include "mrl.h"

void test_alphabet_creation() {
    Alphabet *alphabet = create_alphabet();
    assert(alphabet != NULL);
    
    Generator *g1 = create_generator("A", 1, 1);
    alphabet_add(alphabet, g1);
    
    Generator *found = alphabet_find_full(alphabet, "A", 1, 1);
    assert(found == g1);
    assert(strcmp(found->name, "A") == 0);
    
    printf("test_alphabet_creation passed\n");
}

void test_get_or_create_generator() {
    Alphabet *alphabet = NULL;
    Generator *g1 = get_or_create_generator(&alphabet, "B", 0, 1);
    
    assert(alphabet != NULL);
    assert(g1 != NULL);
    assert(strcmp(g1->name, "B") == 0);
    
    Generator *g2 = get_or_create_generator(&alphabet, "B", 0, 1);
    assert(g1 == g2);
    
    printf("test_get_or_create_generator passed\n");
}

int main() {
    test_alphabet_creation();
    test_get_or_create_generator();
    printf("All MRL unit tests passed!\n");
    return 0;
}
