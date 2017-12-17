#include "unit.h"
#include <dst/dst.h>

int main() {
    DstParseResult pres;
    DstCompileOptions opts;
    DstCompileResults cres;
    DstFunction *func;

    FILE *f = fopen("./dsttest/basic.dst", "rb");
    fseek(f, 0, SEEK_END);
    long fsize = ftell(f);
    fseek(f, 0, SEEK_SET);  //same as rewind(f);

    char *string = malloc(fsize + 1);
    fread(string, fsize, 1, f);
    fclose(f);

    string[fsize] = 0;

    dst_init();

    pres = dst_parsec(string);
    free(string);

    if (pres.status == DST_PARSE_ERROR) {
        dst_puts(dst_formatc("parse error at %d: %S\n", pres.bytes_read, pres.error));
        return 1;
    }
    assert(pres.status == DST_PARSE_OK);
    dst_puts(dst_formatc("\nparse result: %v\n\n", pres.value));

    opts.flags = 0;
    opts.source = pres.value;
    opts.sourcemap = pres.map;

    cres = dst_compile(opts);
    if (cres.status == DST_COMPILE_ERROR) {
        dst_puts(dst_formatc("compilation error: %S\n", cres.error));
        dst_puts(dst_formatc("error location: %d, %d\n", cres.error_start, cres.error_end));
        return 1;
    }
    assert(cres.status == DST_COMPILE_OK);

    dst_puts(dst_formatc("\nfuncdef: %v\n\n", dst_disasm(cres.funcdef)));
    
    func = dst_compile_func(cres);
    
    dst_run(dst_wrap_function(func));
    dst_puts(dst_formatc("result: %v\n", dst_vm_fiber->ret));

    dst_deinit();

    return 0;
}