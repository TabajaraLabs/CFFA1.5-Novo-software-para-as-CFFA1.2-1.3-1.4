`timescale 1ns/1ps
// Teste dirigido da v1.6 (barramento do Apple IIe aproximado) + pulso espurio no /DEVSEL
module tb3;
  reg [15:0] addr; reg RW=1, nDEVSEL=1, nIOSEL=1, nIOSTRB=1, CLK7M=0;
  wire [13:0] d; wire nWE; wire BK13,BK14; pullup(BK13); pullup(BK14);
  cffa_core_v16 D(.A0(addr[0]),.A1(addr[1]),.A2(addr[2]),.A3(addr[3]),.A8(addr[8]),.A9(addr[9]),.A10(addr[10]),.RW(RW),
   .nDEVSEL(nDEVSEL),.nIOSEL(nIOSEL),.nIOSTRB(nIOSTRB),.CLK7M(CLK7M),
   .nR_HOST(d[0]),.R_ATA(d[1]),.W_HOST(d[2]),.nW_ATA(d[3]),.nIOWR(d[4]),.nIORD(d[5]),.nCS0(d[6]),.nCS1(d[7]),.nDBUS245(d[8]),.nEPROM_EN(d[9]),.NOT_RW(d[10]),.LA0(d[11]),.LA1(d[12]),.LA2(d[13]),.nWE(nWE),.BK13(BK13),.BK14(BK14));
  initial begin #0.5; forever #69.8 CLK7M=~CLK7M; end
  real tfall; integer npulse=0, erros=0;
  always @(negedge nWE) tfall=$realtime;
  always @(posedge nWE) npulse=npulse+1;
  task ciclo(input [15:0] a, input r); begin
    addr=a; RW=r; #489;
    if(a[15:4]==12'hC0F) nDEVSEL=0;
    if(a[15:8]==8'hC7) nIOSEL=0;
    if(a>=16'hC800 && a<=16'hCFFF) nIOSTRB=0;
    #489; nDEVSEL=1; nIOSEL=1; nIOSTRB=1;
  end endtask
  task conf(input esperado, input [8*40-1:0] txt); begin
    #5; if(BK14!==esperado) begin erros=erros+1; $display("ERRO  %0s: A14=%b (esperado %b)",txt,BK14,esperado); end
    else $display("ok    %0s: A14=%b",txt,BK14);
  end endtask
  integer n0,k;
  initial begin
    addr=0; #1000;
    conf(0,"power-up");
    ciclo(16'hC0F5,1); conf(1,"leitura $C0F5");
    ciclo(16'hC0F4,0); conf(0,"escrita $C0F4");
    ciclo(16'hC0F5,0); conf(1,"escrita $C0F5");
    ciclo(16'hC0F4,1); conf(0,"leitura $C0F4");
    // pulsos espurios de 25 ns no /DEVSEL, em varias fases do 7M, com o endereco $C0F5 e escrita
    for(k=0;k<140;k=k+7) begin addr=16'hC0F5; RW=0; #(489+k); nDEVSEL=0; #25; nDEVSEL=1; #(489-k-25); end
    conf(0,"20 pulsos espurios de 25 ns em $C0F5");
    // gravacao
    ciclo(16'hC700,1);
    n0=npulse; ciclo(16'hC810,0); if(npulse!=n0) begin erros=erros+1; $display("ERRO gravou travada"); end else $display("ok    escrita travada nao grava");
    ciclo(16'hC0F3,0);
    n0=npulse; ciclo(16'hC810,0); ciclo(16'hC811,0); if(npulse-n0!=2) begin erros=erros+1; $display("ERRO destravada: %0d pulsos",npulse-n0); end else $display("ok    destravada: 2 pulsos /WE");
    ciclo(16'hC0F5,1); conf(1,"leitura $C0F5 depois de gravar");
    n0=npulse; ciclo(16'hC812,0); if(npulse!=n0) begin erros=erros+1; $display("ERRO $C0F5 nao travou"); end else $display("ok    acesso a $C0F5 travou a gravacao");
    ciclo(16'hC0F3,0); ciclo(16'hC0F3,1);
    n0=npulse; ciclo(16'hC813,0); if(npulse!=n0) begin erros=erros+1; $display("ERRO leitura $C0F3 nao travou"); end else $display("ok    leitura $C0F3 travou");
    $display("TOTAL DE ERROS: %0d", erros); $finish;
  end
endmodule
