// test cases for rule CWE-611 (createLSParser)

#include "tests.h"

// ---

class DOMLSParser : public AbstractDOMParser {
};

class DOMImplementationLS {
public:
	DOMLSParser *createLSParser();
};

// ---

void test5_1(DOMImplementationLS *impl, InputSource &data) {
	DOMLSParser *p = impl->createLSParser();

	p->parse(data); // BAD (parser not correctly configured)
}

void test5_2(DOMImplementationLS *impl, InputSource &data) {
	DOMLSParser *p = impl->createLSParser();

	p->setDisableDefaultEntityResolution(true);
	p->parse(data); // GOOD
}

DOMImplementationLS *g_impl;
DOMLSParser *g_p1, *g_p2;
InputSource *g_data;

void test5_3_init() {
	g_p1 = g_impl->createLSParser();
	g_p1->setDisableDefaultEntityResolution(true);

	g_p2 = g_impl->createLSParser();
}

void test5_3() {
	test5_3_init();

	g_p1->parse(*g_data); // GOOD
	g_p2->parse(*g_data); // BAD (parser not correctly configured) [NOT DETECTED]
}
