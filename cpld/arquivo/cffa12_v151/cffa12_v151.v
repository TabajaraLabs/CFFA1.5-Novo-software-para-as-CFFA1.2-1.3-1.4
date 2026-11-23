// cffa12_v151.v - topo para a CFFA v1.2 do Rich Dreher (EPM7064SLC44-10), logica v1.5.1 - 2026-11-20 (v1.5 + estado inicial garantido dos registradores)
// Pinos novos: 8 = /WE da EEPROM ; 27 = A14 da ROM por software (dreno aberto).
// O pino 24 (CS_MASK na v1.4) fica sem uso: nao sabemos se ele esta ligado na placa v1.2.
module cffa12_v151 (
    input  wire A0, A1, A2, A3, A8, A9, A10, RW, nDEVSEL, nIOSEL, nIOSTRB, CLK7M,
    output wire nR_HOST, R_ATA, W_HOST, nW_ATA, nIOWR, nIORD, nCS0, nCS1,
    output wire nDBUS245, nEPROM_EN, NOT_RW, LA0, LA1, LA2,
    output wire nWE,
    inout  wire BK14
);
    wire bk13_nc;
    cffa_core_v15 u (.A0(A0),.A1(A1),.A2(A2),.A3(A3),.A8(A8),.A9(A9),.A10(A10),.RW(RW),
        .nDEVSEL(nDEVSEL),.nIOSEL(nIOSEL),.nIOSTRB(nIOSTRB),.CLK7M(CLK7M),
        .nR_HOST(nR_HOST),.R_ATA(R_ATA),.W_HOST(W_HOST),.nW_ATA(nW_ATA),.nIOWR(nIOWR),.nIORD(nIORD),
        .nCS0(nCS0),.nCS1(nCS1),.nDBUS245(nDBUS245),.nEPROM_EN(nEPROM_EN),.NOT_RW(NOT_RW),
        .LA0(LA0),.LA1(LA1),.LA2(LA2),.nWE(nWE),.BK13(bk13_nc),.BK14(BK14));
endmodule
