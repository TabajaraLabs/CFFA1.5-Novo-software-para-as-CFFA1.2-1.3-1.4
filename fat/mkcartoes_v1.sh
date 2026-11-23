set -e
mk() { # $1 nome  $2 MB  $3 fat  $4 mbr(1/0)
  img=$1; rm -f $img; truncate -s ${2}M $img
  if [ $4 = 1 ]; then
    python3 -c "
import struct,sys
f=open('$img','r+b'); n=$2*2048
t=0x0C if $3==32 else 0x06
e=bytes([0,0,0,0,t,0,0,0])+struct.pack('<II',2048,n-2048)
f.seek(446); f.write(e); f.seek(510); f.write(b'\x55\xaa')" 
    mkfs.fat -F $3 --offset 2048 -n CFFATESTE $img >/dev/null; T="$img@@1M"
  else
    mkfs.fat -F $3 -n CFFATESTE $img >/dev/null; T="$img"
  fi
  head -c 819200 /dev/urandom > /tmp/t1.po
  head -c 33554432 /dev/urandom > /tmp/hd32.po
  echo ola > /tmp/notas.txt
  mcopy -i $T /tmp/notas.txt ::NOTAS.TXT
  mcopy -i $T /tmp/t1.po ::TESTE1.PO
  mcopy -i $T /tmp/hd32.po ::HD32.PO
  # fragmentado: A, B, apaga A, grava C maior que A
  head -c 100000 /dev/urandom > /tmp/a; head -c 5000 /dev/urandom > /tmp/b; head -c 409600 /dev/urandom > /tmp/c.img
  mcopy -i $T /tmp/a ::A.BIN; mcopy -i $T /tmp/b ::B.BIN; mdel -i $T ::A.BIN
  mcopy -i $T /tmp/c.img ::FRAG.IMG
  mmd -i $T ::PASTA
  mcopy -i $T /tmp/notas.txt "::Nome Comprido Teste.HDV"
  mdir -i $T ::
}
mk c32.img 64 32 1
mk c16.img 64 16 0
