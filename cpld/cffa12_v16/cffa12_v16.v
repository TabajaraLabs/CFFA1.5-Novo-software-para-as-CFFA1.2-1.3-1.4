// cffa12_v16.v - topo para a CFFA v1.2 do Rich Dreher (EPM7064SLC44-10), logica v1.6 - 2026-11-20
// Pinos novos: 8 = /WE da EEPROM ; 27 = A14 da ROM por software (dreno aberto, precisa de pull-up de 10k).
// $C0F3 escrita = destrava gravacao, leitura = trava ; $C0F4 = banco baixo (A14=0) ; $C0F5 = banco alto (A14=1).
// O pino 24 (CS_MASK na v1.4) fica sem uso: nao sabemos se ele esta ligado na placa v1.2.
module cffa12_v16 (
    input  wire A0, A1, A2, A3, A8, A9, A10, RW, nDEVSEL, nIOSEL, nIOSTRB, CLK7M,
    output wire nR_HOST, R_ATA, W_HOST, nW_ATA, nIOWR, nIORD, nCS0, nCS1,
    output wire nDBUS245, nEPROM_EN, NOT_RW, LA0, LA1, LA2,
    output wire nWE,
    inout  wire BK14
);
    wire bk13_nc;
    cffa_core_v16 u (.A0(A0),.A1(A1),.A2(A2),.A3(A3),.A8(A8),.A9(A9),.A10(A10),.RW(RW),
        .nDEVSEL(nDEVSEL),.nIOSEL(nIOSEL),.nIOSTRB(nIOSTRB),.CLK7M(CLK7M),
        .nR_HOST(nR_HOST),.R_ATA(R_ATA),.W_HOST(W_HOST),.nW_ATA(nW_ATA),.nIOWR(nIOWR),.nIORD(nIORD),
        .nCS0(nCS0),.nCS1(nCS1),.nDBUS245(nDBUS245),.nEPROM_EN(nEPROM_EN),.NOT_RW(NOT_RW),
        .LA0(LA0),.LA1(LA1),.LA2(LA2),.nWE(nWE),.BK13(bk13_nc),.BK14(BK14));
endmodule
