#ifndef NC2VICIO_H_
#define NC2VICIO_H_

#endif /*NC2VICIO_H_*/

#define ASCII_FLOAT_FORMAT "%f \t"
#define SCIENTIFIC_FLOAT_FORMAT "%.7e \t"



int fprintln(FILE* stream, const char* format, ...);


/**
 * Safely opens a file. On error, exit(FALSE) is called
 */
 FILE* safefopen(const char* filename, const char* mode);
 
  /**
  * Safely flushes and closes a file. On failure an attempt to close is made, then
  * exit(0) is called.
  */
  
 void safefclose(FILE* fp);
