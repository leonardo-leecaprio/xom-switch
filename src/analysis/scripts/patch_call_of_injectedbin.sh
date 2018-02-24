#!/bin/bash
if [ $# -ne 5 ]; then
    echo ""
    echo "  [USAGE] <program> <symbol name> <corresponding syscall in ld.so> "\
         "<binary to patch> <injected binary> <original binary>"
    echo ""
    echo "  [NOTE]: this program patches symbols in injected binary to target "\
         "its corresponding syscall wrapper in ld.so"
    echo "  e.g.: the wrapper of mmap is mmap; the wrapper of writev is "\
         "actually _dl_debug_vdprintf (simple version of printf)"
    echo ""
    exit 1
fi
callname=$1
syscall=$2
exe=$3
injectexe=$4
origexe=$5
progdir=$(readlink -f $(dirname $0))
syscalladdr=$($progdir/analyze_syscall.sh $syscall $origexe)
echo "$syscall wrapper function address: $syscalladdr"
textoffset=$(r2 -A -qc "iS~.text[1]" $injectexe)
echo $textoffset
textoffset4BC=$(printf "%X" $textoffset)
#we preserve the offset within page
offsetinpage=$(echo "obase=10; ibase=16; $textoffset4BC % 1000" | bc)
echo "offset in page: $offsetinpage"
offsetinpageHEX=$(printf "0x%x" $offsetinpage)
echo "offset in page (hex): $offsetinpageHEX"

topatchoffset=$(r2 -A -qc "is~$callname[1]" $injectexe)
echo $topatchoffset
offset=$((topatchoffset - textoffset))
base=$(r2 -A -qc "iS~.instrumented_code[3]" $exe)
echo $base

patchaddr=$((base + offset + offsetinpage))
echo "address to patch: $patchaddr"
r2 -Aw -qc "s $patchaddr; wa jmp $syscalladdr; save; quit" $exe

