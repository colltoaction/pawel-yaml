#ifndef NODE_TOKENS_H
#define NODE_TOKENS_H

/* Node tokens largely overlap with Stream tokens but exclude stream control */
/* Ideally we would import them or define them distinctly.
 * For now, assuming they share the same enum values for simplicity in lexer interaction.
 * If they needed to be distinct, we'd need separate enums and a translation layer.
 * Using stream_tokens.h as the "master" list for shared tokens.
 */
#include "stream_tokens.h"

#endif
