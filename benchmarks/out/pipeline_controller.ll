; ModuleID = '/tmp/.tmpbnQpPU/benchmarks/pipeline_controller.st.ll'
source_filename = "/workspaces/ICSPrism/benchmarks/pipeline_controller.st"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%__vtable_PipelineCtrl = type { ptr }
%PLC_PRG = type { i16, i16, i16, i16, i16, i16, i8, %PipelineCtrl }
%PipelineCtrl = type { ptr, i16, i16, i16, i16, i16, i16, i8, i8, i8, i16, i16, i16, i16, i16, i16, i16, i16, i16, i16, [64 x i16], i16, i16 }

@PHASE_IDLE = unnamed_addr constant i8 0
@PHASE_PRIME = unnamed_addr constant i8 1
@PHASE_FLOW = unnamed_addr constant i8 2
@PHASE_FILL = unnamed_addr constant i8 3
@__vtable_PipelineCtrl_instance = global %__vtable_PipelineCtrl zeroinitializer
@PLC_PRG_instance = global %PLC_PRG zeroinitializer
@llvm.global_ctors = appending global [1 x { i32, ptr, ptr }] [{ i32, ptr, ptr } { i32 65535, ptr @__unit_pipeline_controller_st__ctor, ptr null }]

define void @PipelineCtrl(ptr %0) {
entry:
  %this = alloca ptr, align 8
  store ptr %0, ptr %this, align 8
  %__vtable = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 0
  %PumpRate = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 1
  %ValvePos = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 2
  %PipeTemp = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 3
  %BackPressure = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 4
  %FeedConc = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 5
  %CoolantRate = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 6
  %Cmd = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 7
  %Status = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 8
  %Phase = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 9
  %CycleCount = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 10
  %PrimeCycles = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 11
  %PrimeScore = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 12
  %FluxScore = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 13
  %FluxSum = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 14
  %FlowAccum = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 15
  %PressAccum = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 16
  %TempAccum = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 17
  %PhaseCounter = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 18
  %FillHead = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 19
  %Buffer = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 20
  %PVsum = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 21
  %i = getelementptr inbounds nuw %PipelineCtrl, ptr %0, i32 0, i32 22
  %load_CycleCount = load i16, ptr %CycleCount, align 2
  %1 = sext i16 %load_CycleCount to i32
  %tmpVar = add i32 %1, 1
  %2 = trunc i32 %tmpVar to i16
  store i16 %2, ptr %CycleCount, align 2
  %load_Phase = load i8, ptr %Phase, align 1
  %ran_once_0 = alloca i8, align 1
  %is_incrementing_0 = alloca i8, align 1
  switch i8 %load_Phase, label %else [
    i8 0, label %case
    i8 1, label %case23
    i8 2, label %case52
    i8 3, label %case84
  ]

case:                                             ; preds = %entry
  %load_Cmd = load i8, ptr %Cmd, align 1
  %3 = sext i8 %load_Cmd to i32
  %tmpVar2 = icmp eq i32 %3, 1
  %4 = zext i1 %tmpVar2 to i8
  %5 = icmp ne i8 %4, 0
  br i1 %5, label %condition_body, label %continue1

case23:                                           ; preds = %entry
  %load_PrimeCycles = load i16, ptr %PrimeCycles, align 2
  %6 = sext i16 %load_PrimeCycles to i32
  %tmpVar24 = add i32 %6, 1
  %7 = trunc i32 %tmpVar24 to i16
  store i16 %7, ptr %PrimeCycles, align 2
  %load_PumpRate = load i16, ptr %PumpRate, align 2
  %8 = sext i16 %load_PumpRate to i32
  %load_BackPressure = load i16, ptr %BackPressure, align 2
  %9 = sext i16 %load_BackPressure to i32
  %tmpVar25 = add i32 %8, %9
  %10 = trunc i32 %tmpVar25 to i16
  store i16 %10, ptr %PVsum, align 2
  %load_PrimeCycles27 = load i16, ptr %PrimeCycles, align 2
  %11 = sext i16 %load_PrimeCycles27 to i32
  %tmpVar28 = srem i32 %11, 3
  %tmpVar29 = icmp eq i32 %tmpVar28, 0
  %12 = zext i1 %tmpVar29 to i8
  %13 = icmp ne i8 %12, 0
  br i1 %13, label %condition_body30, label %continue26

case52:                                           ; preds = %entry
  %load_PipeTemp = load i16, ptr %PipeTemp, align 2
  %14 = sext i16 %load_PipeTemp to i32
  %load_CoolantRate = load i16, ptr %CoolantRate, align 2
  %15 = sext i16 %load_CoolantRate to i32
  %tmpVar53 = add i32 %14, %15
  %16 = trunc i32 %tmpVar53 to i16
  store i16 %16, ptr %FluxSum, align 2
  %load_FluxSum = load i16, ptr %FluxSum, align 2
  %17 = sext i16 %load_FluxSum to i32
  %tmpVar56 = icmp sge i32 %17, 80
  %18 = zext i1 %tmpVar56 to i8
  %19 = icmp ne i8 %18, 0
  %load_FluxSum57 = load i16, ptr %FluxSum, align 2
  %20 = sext i16 %load_FluxSum57 to i32
  %tmpVar58 = icmp sle i32 %20, 160
  %21 = zext i1 %tmpVar58 to i8
  %22 = icmp ne i8 %21, 0
  %23 = and i1 %19, %22
  %24 = zext i1 %23 to i8
  %25 = icmp ne i8 %24, 0
  %load_FeedConc = load i16, ptr %FeedConc, align 2
  %26 = sext i16 %load_FeedConc to i32
  %tmpVar59 = icmp sge i32 %26, 20
  %27 = zext i1 %tmpVar59 to i8
  %28 = icmp ne i8 %27, 0
  %29 = and i1 %25, %28
  %30 = zext i1 %29 to i8
  %31 = icmp ne i8 %30, 0
  %load_FeedConc60 = load i16, ptr %FeedConc, align 2
  %32 = sext i16 %load_FeedConc60 to i32
  %tmpVar61 = icmp sle i32 %32, 70
  %33 = zext i1 %tmpVar61 to i8
  %34 = icmp ne i8 %33, 0
  %35 = and i1 %31, %34
  %36 = zext i1 %35 to i8
  %37 = icmp ne i8 %36, 0
  br i1 %37, label %condition_body62, label %else54

case84:                                           ; preds = %entry
  %load_PhaseCounter = load i16, ptr %PhaseCounter, align 2
  %38 = sext i16 %load_PhaseCounter to i32
  %tmpVar85 = add i32 %38, 1
  %39 = trunc i32 %tmpVar85 to i16
  store i16 %39, ptr %PhaseCounter, align 2
  %load_PumpRate88 = load i16, ptr %PumpRate, align 2
  %40 = sext i16 %load_PumpRate88 to i32
  %tmpVar89 = icmp sge i32 %40, 40
  %41 = zext i1 %tmpVar89 to i8
  %42 = icmp ne i8 %41, 0
  %load_PumpRate90 = load i16, ptr %PumpRate, align 2
  %43 = sext i16 %load_PumpRate90 to i32
  %tmpVar91 = icmp sle i32 %43, 90
  %44 = zext i1 %tmpVar91 to i8
  %45 = icmp ne i8 %44, 0
  %46 = and i1 %42, %45
  %47 = zext i1 %46 to i8
  %48 = icmp ne i8 %47, 0
  br i1 %48, label %condition_body92, label %else86

else:                                             ; preds = %entry
  br label %continue

continue:                                         ; preds = %continue148, %continue80, %continue48, %continue1, %else
  %load_Phase323 = load i8, ptr %Phase, align 1
  store i8 %load_Phase323, ptr %Status, align 1
  ret void

condition_body:                                   ; preds = %case
  store i8 0, ptr %ran_once_0, align 1
  store i8 0, ptr %is_incrementing_0, align 1
  store i16 0, ptr %i, align 2
  store i8 1, ptr %is_incrementing_0, align 1
  br label %while_body

continue1:                                        ; preds = %continue3, %case
  br label %continue

while_body:                                       ; preds = %continue8, %condition_body
  %load_ran_once_0 = load i8, ptr %ran_once_0, align 1
  %49 = icmp ne i8 %load_ran_once_0, 0
  br i1 %49, label %condition_body5, label %continue4

continue3:                                        ; preds = %condition_body17, %condition_body13
  store i16 0, ptr %PrimeCycles, align 2
  store i16 0, ptr %PrimeScore, align 2
  store i16 0, ptr %FluxScore, align 2
  store i16 0, ptr %FlowAccum, align 2
  store i16 0, ptr %PressAccum, align 2
  store i16 0, ptr %TempAccum, align 2
  store i16 0, ptr %PhaseCounter, align 2
  store i16 0, ptr %FillHead, align 2
  store i16 0, ptr %PVsum, align 2
  store i8 1, ptr %Phase, align 1
  br label %continue1

condition_body5:                                  ; preds = %while_body
  %load_i = load i16, ptr %i, align 2
  %50 = sext i16 %load_i to i32
  %tmpVar6 = add i32 %50, 1
  %51 = trunc i32 %tmpVar6 to i16
  store i16 %51, ptr %i, align 2
  br label %continue4

continue4:                                        ; preds = %condition_body5, %while_body
  store i8 1, ptr %ran_once_0, align 1
  %load_is_incrementing_0 = load i8, ptr %is_incrementing_0, align 1
  %52 = icmp ne i8 %load_is_incrementing_0, 0
  br i1 %52, label %condition_body9, label %else7

condition_body9:                                  ; preds = %continue4
  %load_i11 = load i16, ptr %i, align 2
  %53 = sext i16 %load_i11 to i32
  %tmpVar12 = icmp sgt i32 %53, 63
  %54 = zext i1 %tmpVar12 to i8
  %55 = icmp ne i8 %54, 0
  br i1 %55, label %condition_body13, label %continue10

else7:                                            ; preds = %continue4
  %load_i15 = load i16, ptr %i, align 2
  %56 = sext i16 %load_i15 to i32
  %tmpVar16 = icmp slt i32 %56, 63
  %57 = zext i1 %tmpVar16 to i8
  %58 = icmp ne i8 %57, 0
  br i1 %58, label %condition_body17, label %continue14

continue8:                                        ; preds = %continue14, %continue10
  %load_i19 = load i16, ptr %i, align 2
  %59 = sext i16 %load_i19 to i32
  %tmpVar20 = mul i32 1, %59
  %tmpVar21 = add i32 %tmpVar20, 0
  %tmpVar22 = getelementptr inbounds [64 x i16], ptr %Buffer, i32 0, i32 %tmpVar21
  store i16 0, ptr %tmpVar22, align 2
  br label %while_body

condition_body13:                                 ; preds = %condition_body9
  br label %continue3

buffer_block:                                     ; No predecessors!
  br label %continue10

continue10:                                       ; preds = %buffer_block, %condition_body9
  br label %continue8

condition_body17:                                 ; preds = %else7
  br label %continue3

buffer_block18:                                   ; No predecessors!
  br label %continue14

continue14:                                       ; preds = %buffer_block18, %else7
  br label %continue8

condition_body30:                                 ; preds = %case23
  %load_PVsum = load i16, ptr %PVsum, align 2
  %60 = sext i16 %load_PVsum to i32
  %tmpVar33 = icmp sge i32 %60, 80
  %61 = zext i1 %tmpVar33 to i8
  %62 = icmp ne i8 %61, 0
  %load_PVsum34 = load i16, ptr %PVsum, align 2
  %63 = sext i16 %load_PVsum34 to i32
  %tmpVar35 = icmp sle i32 %63, 160
  %64 = zext i1 %tmpVar35 to i8
  %65 = icmp ne i8 %64, 0
  %66 = and i1 %62, %65
  %67 = zext i1 %66 to i8
  %68 = icmp ne i8 %67, 0
  %load_ValvePos = load i16, ptr %ValvePos, align 2
  %69 = sext i16 %load_ValvePos to i32
  %tmpVar36 = icmp sge i32 %69, 15
  %70 = zext i1 %tmpVar36 to i8
  %71 = icmp ne i8 %70, 0
  %72 = and i1 %68, %71
  %73 = zext i1 %72 to i8
  %74 = icmp ne i8 %73, 0
  %load_ValvePos37 = load i16, ptr %ValvePos, align 2
  %75 = sext i16 %load_ValvePos37 to i32
  %tmpVar38 = icmp sle i32 %75, 60
  %76 = zext i1 %tmpVar38 to i8
  %77 = icmp ne i8 %76, 0
  %78 = and i1 %74, %77
  %79 = zext i1 %78 to i8
  %80 = icmp ne i8 %79, 0
  br i1 %80, label %condition_body39, label %else31

continue26:                                       ; preds = %continue32, %case23
  %load_PrimeScore49 = load i16, ptr %PrimeScore, align 2
  %81 = sext i16 %load_PrimeScore49 to i32
  %tmpVar50 = icmp sge i32 %81, 8
  %82 = zext i1 %tmpVar50 to i8
  %83 = icmp ne i8 %82, 0
  br i1 %83, label %condition_body51, label %continue48

condition_body39:                                 ; preds = %condition_body30
  %load_PrimeScore = load i16, ptr %PrimeScore, align 2
  %84 = sext i16 %load_PrimeScore to i32
  %tmpVar40 = add i32 %84, 1
  %85 = trunc i32 %tmpVar40 to i16
  store i16 %85, ptr %PrimeScore, align 2
  br label %continue32

else31:                                           ; preds = %condition_body30
  %load_PrimeScore43 = load i16, ptr %PrimeScore, align 2
  %86 = sext i16 %load_PrimeScore43 to i32
  %tmpVar44 = icmp sgt i32 %86, 1
  %87 = zext i1 %tmpVar44 to i8
  %88 = icmp ne i8 %87, 0
  br i1 %88, label %condition_body45, label %else41

continue32:                                       ; preds = %continue42, %condition_body39
  br label %continue26

condition_body45:                                 ; preds = %else31
  %load_PrimeScore46 = load i16, ptr %PrimeScore, align 2
  %89 = sext i16 %load_PrimeScore46 to i32
  %tmpVar47 = sub i32 %89, 2
  %90 = trunc i32 %tmpVar47 to i16
  store i16 %90, ptr %PrimeScore, align 2
  br label %continue42

else41:                                           ; preds = %else31
  store i16 0, ptr %PrimeScore, align 2
  br label %continue42

continue42:                                       ; preds = %else41, %condition_body45
  br label %continue32

condition_body51:                                 ; preds = %continue26
  store i8 2, ptr %Phase, align 1
  br label %continue48

continue48:                                       ; preds = %condition_body51, %continue26
  br label %continue

condition_body62:                                 ; preds = %case52
  %load_FluxScore = load i16, ptr %FluxScore, align 2
  %91 = sext i16 %load_FluxScore to i32
  %tmpVar63 = add i32 %91, 1
  %92 = trunc i32 %tmpVar63 to i16
  store i16 %92, ptr %FluxScore, align 2
  br label %continue55

else54:                                           ; preds = %case52
  %load_FluxScore66 = load i16, ptr %FluxScore, align 2
  %93 = sext i16 %load_FluxScore66 to i32
  %tmpVar67 = icmp sgt i32 %93, 1
  %94 = zext i1 %tmpVar67 to i8
  %95 = icmp ne i8 %94, 0
  br i1 %95, label %condition_body68, label %else64

continue55:                                       ; preds = %continue65, %condition_body62
  %load_CycleCount72 = load i16, ptr %CycleCount, align 2
  %96 = sext i16 %load_CycleCount72 to i32
  %tmpVar73 = srem i32 %96, 11
  %tmpVar74 = icmp eq i32 %tmpVar73, 0
  %97 = zext i1 %tmpVar74 to i8
  %98 = icmp ne i8 %97, 0
  %load_FluxScore75 = load i16, ptr %FluxScore, align 2
  %99 = sext i16 %load_FluxScore75 to i32
  %tmpVar76 = icmp sgt i32 %99, 0
  %100 = zext i1 %tmpVar76 to i8
  %101 = icmp ne i8 %100, 0
  %102 = and i1 %98, %101
  %103 = zext i1 %102 to i8
  %104 = icmp ne i8 %103, 0
  br i1 %104, label %condition_body77, label %continue71

condition_body68:                                 ; preds = %else54
  %load_FluxScore69 = load i16, ptr %FluxScore, align 2
  %105 = sext i16 %load_FluxScore69 to i32
  %tmpVar70 = sub i32 %105, 2
  %106 = trunc i32 %tmpVar70 to i16
  store i16 %106, ptr %FluxScore, align 2
  br label %continue65

else64:                                           ; preds = %else54
  store i16 0, ptr %FluxScore, align 2
  br label %continue65

continue65:                                       ; preds = %else64, %condition_body68
  br label %continue55

condition_body77:                                 ; preds = %continue55
  %load_FluxScore78 = load i16, ptr %FluxScore, align 2
  %107 = sext i16 %load_FluxScore78 to i32
  %tmpVar79 = sdiv i32 %107, 2
  %108 = trunc i32 %tmpVar79 to i16
  store i16 %108, ptr %FluxScore, align 2
  br label %continue71

continue71:                                       ; preds = %condition_body77, %continue55
  %load_FluxScore81 = load i16, ptr %FluxScore, align 2
  %109 = sext i16 %load_FluxScore81 to i32
  %tmpVar82 = icmp sge i32 %109, 8
  %110 = zext i1 %tmpVar82 to i8
  %111 = icmp ne i8 %110, 0
  br i1 %111, label %condition_body83, label %continue80

condition_body83:                                 ; preds = %continue71
  store i8 3, ptr %Phase, align 1
  br label %continue80

continue80:                                       ; preds = %condition_body83, %continue71
  br label %continue

condition_body92:                                 ; preds = %case84
  %load_FlowAccum = load i16, ptr %FlowAccum, align 2
  %112 = sext i16 %load_FlowAccum to i32
  %tmpVar93 = add i32 %112, 1
  %113 = trunc i32 %tmpVar93 to i16
  store i16 %113, ptr %FlowAccum, align 2
  br label %continue87

else86:                                           ; preds = %case84
  %load_FlowAccum96 = load i16, ptr %FlowAccum, align 2
  %114 = sext i16 %load_FlowAccum96 to i32
  %tmpVar97 = icmp sgt i32 %114, 1
  %115 = zext i1 %tmpVar97 to i8
  %116 = icmp ne i8 %115, 0
  br i1 %116, label %condition_body98, label %else94

continue87:                                       ; preds = %continue95, %condition_body92
  %load_BackPressure103 = load i16, ptr %BackPressure, align 2
  %117 = sext i16 %load_BackPressure103 to i32
  %tmpVar104 = icmp sge i32 %117, 30
  %118 = zext i1 %tmpVar104 to i8
  %119 = icmp ne i8 %118, 0
  %load_BackPressure105 = load i16, ptr %BackPressure, align 2
  %120 = sext i16 %load_BackPressure105 to i32
  %tmpVar106 = icmp sle i32 %120, 80
  %121 = zext i1 %tmpVar106 to i8
  %122 = icmp ne i8 %121, 0
  %123 = and i1 %119, %122
  %124 = zext i1 %123 to i8
  %125 = icmp ne i8 %124, 0
  br i1 %125, label %condition_body107, label %else101

condition_body98:                                 ; preds = %else86
  %load_FlowAccum99 = load i16, ptr %FlowAccum, align 2
  %126 = sext i16 %load_FlowAccum99 to i32
  %tmpVar100 = sub i32 %126, 2
  %127 = trunc i32 %tmpVar100 to i16
  store i16 %127, ptr %FlowAccum, align 2
  br label %continue95

else94:                                           ; preds = %else86
  store i16 0, ptr %FlowAccum, align 2
  br label %continue95

continue95:                                       ; preds = %else94, %condition_body98
  br label %continue87

condition_body107:                                ; preds = %continue87
  %load_PressAccum = load i16, ptr %PressAccum, align 2
  %128 = sext i16 %load_PressAccum to i32
  %tmpVar108 = add i32 %128, 1
  %129 = trunc i32 %tmpVar108 to i16
  store i16 %129, ptr %PressAccum, align 2
  br label %continue102

else101:                                          ; preds = %continue87
  %load_PressAccum110 = load i16, ptr %PressAccum, align 2
  %130 = sext i16 %load_PressAccum110 to i32
  %tmpVar111 = icmp sgt i32 %130, 0
  %131 = zext i1 %tmpVar111 to i8
  %132 = icmp ne i8 %131, 0
  br i1 %132, label %condition_body112, label %continue109

continue102:                                      ; preds = %continue109, %condition_body107
  %load_PipeTemp117 = load i16, ptr %PipeTemp, align 2
  %133 = sext i16 %load_PipeTemp117 to i32
  %tmpVar118 = icmp sge i32 %133, 50
  %134 = zext i1 %tmpVar118 to i8
  %135 = icmp ne i8 %134, 0
  %load_PipeTemp119 = load i16, ptr %PipeTemp, align 2
  %136 = sext i16 %load_PipeTemp119 to i32
  %tmpVar120 = icmp sle i32 %136, 100
  %137 = zext i1 %tmpVar120 to i8
  %138 = icmp ne i8 %137, 0
  %139 = and i1 %135, %138
  %140 = zext i1 %139 to i8
  %141 = icmp ne i8 %140, 0
  br i1 %141, label %condition_body121, label %else115

condition_body112:                                ; preds = %else101
  %load_PressAccum113 = load i16, ptr %PressAccum, align 2
  %142 = sext i16 %load_PressAccum113 to i32
  %tmpVar114 = sub i32 %142, 1
  %143 = trunc i32 %tmpVar114 to i16
  store i16 %143, ptr %PressAccum, align 2
  br label %continue109

continue109:                                      ; preds = %condition_body112, %else101
  br label %continue102

condition_body121:                                ; preds = %continue102
  %load_TempAccum = load i16, ptr %TempAccum, align 2
  %144 = sext i16 %load_TempAccum to i32
  %tmpVar122 = add i32 %144, 1
  %145 = trunc i32 %tmpVar122 to i16
  store i16 %145, ptr %TempAccum, align 2
  br label %continue116

else115:                                          ; preds = %continue102
  %load_TempAccum125 = load i16, ptr %TempAccum, align 2
  %146 = sext i16 %load_TempAccum125 to i32
  %tmpVar126 = icmp sgt i32 %146, 1
  %147 = zext i1 %tmpVar126 to i8
  %148 = icmp ne i8 %147, 0
  br i1 %148, label %condition_body127, label %else123

continue116:                                      ; preds = %continue124, %condition_body121
  %load_FlowAccum131 = load i16, ptr %FlowAccum, align 2
  %149 = sext i16 %load_FlowAccum131 to i32
  %tmpVar132 = icmp sgt i32 %149, 6
  %150 = zext i1 %tmpVar132 to i8
  %151 = icmp ne i8 %150, 0
  %load_PressAccum133 = load i16, ptr %PressAccum, align 2
  %152 = sext i16 %load_PressAccum133 to i32
  %tmpVar134 = icmp sgt i32 %152, 5
  %153 = zext i1 %tmpVar134 to i8
  %154 = icmp ne i8 %153, 0
  %155 = and i1 %151, %154
  %156 = zext i1 %155 to i8
  %157 = icmp ne i8 %156, 0
  %load_TempAccum135 = load i16, ptr %TempAccum, align 2
  %158 = sext i16 %load_TempAccum135 to i32
  %tmpVar136 = icmp sgt i32 %158, 6
  %159 = zext i1 %tmpVar136 to i8
  %160 = icmp ne i8 %159, 0
  %161 = and i1 %157, %160
  %162 = zext i1 %161 to i8
  %163 = icmp ne i8 %162, 0
  br i1 %163, label %condition_body137, label %continue130

condition_body127:                                ; preds = %else115
  %load_TempAccum128 = load i16, ptr %TempAccum, align 2
  %164 = sext i16 %load_TempAccum128 to i32
  %tmpVar129 = sub i32 %164, 2
  %165 = trunc i32 %tmpVar129 to i16
  store i16 %165, ptr %TempAccum, align 2
  br label %continue124

else123:                                          ; preds = %else115
  store i16 0, ptr %TempAccum, align 2
  br label %continue124

continue124:                                      ; preds = %else123, %condition_body127
  br label %continue116

condition_body137:                                ; preds = %continue116
  %load_PhaseCounter139 = load i16, ptr %PhaseCounter, align 2
  %166 = sext i16 %load_PhaseCounter139 to i32
  %tmpVar140 = srem i32 %166, 4
  %tmpVar141 = icmp eq i32 %tmpVar140, 0
  %167 = zext i1 %tmpVar141 to i8
  %168 = icmp ne i8 %167, 0
  br i1 %168, label %condition_body142, label %continue138

continue130:                                      ; preds = %continue138, %continue116
  %load_PumpRate144 = load i16, ptr %PumpRate, align 2
  %169 = sext i16 %load_PumpRate144 to i32
  %load_ValvePos145 = load i16, ptr %ValvePos, align 2
  %170 = sext i16 %load_ValvePos145 to i32
  %tmpVar146 = add i32 %169, %170
  %171 = trunc i32 %tmpVar146 to i16
  store i16 %171, ptr %PVsum, align 2
  %load_FillHead149 = load i16, ptr %FillHead, align 2
  %172 = sext i16 %load_FillHead149 to i32
  %tmpVar150 = icmp slt i32 %172, 8
  %173 = zext i1 %tmpVar150 to i8
  %174 = icmp ne i8 %173, 0
  br i1 %174, label %condition_body151, label %else147

condition_body142:                                ; preds = %condition_body137
  %load_FillHead = load i16, ptr %FillHead, align 2
  %175 = sext i16 %load_FillHead to i32
  %tmpVar143 = add i32 %175, 1
  %176 = trunc i32 %tmpVar143 to i16
  store i16 %176, ptr %FillHead, align 2
  br label %continue138

continue138:                                      ; preds = %condition_body142, %condition_body137
  br label %continue130

condition_body151:                                ; preds = %continue130
  %load_PVsum153 = load i16, ptr %PVsum, align 2
  %177 = sext i16 %load_PVsum153 to i32
  %tmpVar154 = icmp slt i32 %177, 60
  %178 = zext i1 %tmpVar154 to i8
  %179 = icmp ne i8 %178, 0
  %load_PVsum155 = load i16, ptr %PVsum, align 2
  %180 = sext i16 %load_PVsum155 to i32
  %tmpVar156 = icmp sgt i32 %180, 90
  %181 = zext i1 %tmpVar156 to i8
  %182 = icmp ne i8 %181, 0
  %183 = or i1 %179, %182
  %184 = zext i1 %183 to i8
  %185 = icmp ne i8 %184, 0
  %load_PipeTemp157 = load i16, ptr %PipeTemp, align 2
  %186 = sext i16 %load_PipeTemp157 to i32
  %tmpVar158 = icmp slt i32 %186, 50
  %187 = zext i1 %tmpVar158 to i8
  %188 = icmp ne i8 %187, 0
  %189 = or i1 %185, %188
  %190 = zext i1 %189 to i8
  %191 = icmp ne i8 %190, 0
  %load_PipeTemp159 = load i16, ptr %PipeTemp, align 2
  %192 = sext i16 %load_PipeTemp159 to i32
  %tmpVar160 = icmp sgt i32 %192, 65
  %193 = zext i1 %tmpVar160 to i8
  %194 = icmp ne i8 %193, 0
  %195 = or i1 %191, %194
  %196 = zext i1 %195 to i8
  %197 = icmp ne i8 %196, 0
  br i1 %197, label %condition_body161, label %continue152

else147:                                          ; preds = %continue130
  %load_FillHead171 = load i16, ptr %FillHead, align 2
  %198 = sext i16 %load_FillHead171 to i32
  %tmpVar172 = icmp slt i32 %198, 16
  %199 = zext i1 %tmpVar172 to i8
  %200 = icmp ne i8 %199, 0
  br i1 %200, label %condition_body173, label %else169

continue148:                                      ; preds = %continue170, %continue152
  %load_FillHead318 = load i16, ptr %FillHead, align 2
  %201 = sext i16 %load_FillHead318 to i32
  %tmpVar319 = mul i32 1, %201
  %tmpVar320 = add i32 %tmpVar319, 0
  %tmpVar321 = getelementptr inbounds [64 x i16], ptr %Buffer, i32 0, i32 %tmpVar320
  %load_CycleCount322 = load i16, ptr %CycleCount, align 2
  store i16 %load_CycleCount322, ptr %tmpVar321, align 2
  br label %continue

condition_body161:                                ; preds = %condition_body151
  %load_FillHead164 = load i16, ptr %FillHead, align 2
  %202 = sext i16 %load_FillHead164 to i32
  %tmpVar165 = icmp sgt i32 %202, 5
  %203 = zext i1 %tmpVar165 to i8
  %204 = icmp ne i8 %203, 0
  br i1 %204, label %condition_body166, label %else162

continue152:                                      ; preds = %continue163, %condition_body151
  br label %continue148

condition_body166:                                ; preds = %condition_body161
  %load_FillHead167 = load i16, ptr %FillHead, align 2
  %205 = sext i16 %load_FillHead167 to i32
  %tmpVar168 = sub i32 %205, 6
  %206 = trunc i32 %tmpVar168 to i16
  store i16 %206, ptr %FillHead, align 2
  br label %continue163

else162:                                          ; preds = %condition_body161
  store i16 0, ptr %FillHead, align 2
  br label %continue163

continue163:                                      ; preds = %else162, %condition_body166
  br label %continue152

condition_body173:                                ; preds = %else147
  %load_PVsum175 = load i16, ptr %PVsum, align 2
  %207 = sext i16 %load_PVsum175 to i32
  %tmpVar176 = icmp slt i32 %207, 80
  %208 = zext i1 %tmpVar176 to i8
  %209 = icmp ne i8 %208, 0
  %load_PVsum177 = load i16, ptr %PVsum, align 2
  %210 = sext i16 %load_PVsum177 to i32
  %tmpVar178 = icmp sgt i32 %210, 110
  %211 = zext i1 %tmpVar178 to i8
  %212 = icmp ne i8 %211, 0
  %213 = or i1 %209, %212
  %214 = zext i1 %213 to i8
  %215 = icmp ne i8 %214, 0
  %load_PipeTemp179 = load i16, ptr %PipeTemp, align 2
  %216 = sext i16 %load_PipeTemp179 to i32
  %tmpVar180 = icmp slt i32 %216, 62
  %217 = zext i1 %tmpVar180 to i8
  %218 = icmp ne i8 %217, 0
  %219 = or i1 %215, %218
  %220 = zext i1 %219 to i8
  %221 = icmp ne i8 %220, 0
  %load_PipeTemp181 = load i16, ptr %PipeTemp, align 2
  %222 = sext i16 %load_PipeTemp181 to i32
  %tmpVar182 = icmp sgt i32 %222, 77
  %223 = zext i1 %tmpVar182 to i8
  %224 = icmp ne i8 %223, 0
  %225 = or i1 %221, %224
  %226 = zext i1 %225 to i8
  %227 = icmp ne i8 %226, 0
  br i1 %227, label %condition_body183, label %continue174

else169:                                          ; preds = %else147
  %load_FillHead193 = load i16, ptr %FillHead, align 2
  %228 = sext i16 %load_FillHead193 to i32
  %tmpVar194 = icmp slt i32 %228, 24
  %229 = zext i1 %tmpVar194 to i8
  %230 = icmp ne i8 %229, 0
  br i1 %230, label %condition_body195, label %else191

continue170:                                      ; preds = %continue192, %continue174
  br label %continue148

condition_body183:                                ; preds = %condition_body173
  %load_FillHead186 = load i16, ptr %FillHead, align 2
  %231 = sext i16 %load_FillHead186 to i32
  %tmpVar187 = icmp sgt i32 %231, 5
  %232 = zext i1 %tmpVar187 to i8
  %233 = icmp ne i8 %232, 0
  br i1 %233, label %condition_body188, label %else184

continue174:                                      ; preds = %continue185, %condition_body173
  br label %continue170

condition_body188:                                ; preds = %condition_body183
  %load_FillHead189 = load i16, ptr %FillHead, align 2
  %234 = sext i16 %load_FillHead189 to i32
  %tmpVar190 = sub i32 %234, 6
  %235 = trunc i32 %tmpVar190 to i16
  store i16 %235, ptr %FillHead, align 2
  br label %continue185

else184:                                          ; preds = %condition_body183
  store i16 0, ptr %FillHead, align 2
  br label %continue185

continue185:                                      ; preds = %else184, %condition_body188
  br label %continue174

condition_body195:                                ; preds = %else169
  %load_PVsum197 = load i16, ptr %PVsum, align 2
  %236 = sext i16 %load_PVsum197 to i32
  %tmpVar198 = icmp slt i32 %236, 70
  %237 = zext i1 %tmpVar198 to i8
  %238 = icmp ne i8 %237, 0
  %load_PVsum199 = load i16, ptr %PVsum, align 2
  %239 = sext i16 %load_PVsum199 to i32
  %tmpVar200 = icmp sgt i32 %239, 100
  %240 = zext i1 %tmpVar200 to i8
  %241 = icmp ne i8 %240, 0
  %242 = or i1 %238, %241
  %243 = zext i1 %242 to i8
  %244 = icmp ne i8 %243, 0
  %load_PipeTemp201 = load i16, ptr %PipeTemp, align 2
  %245 = sext i16 %load_PipeTemp201 to i32
  %tmpVar202 = icmp slt i32 %245, 72
  %246 = zext i1 %tmpVar202 to i8
  %247 = icmp ne i8 %246, 0
  %248 = or i1 %244, %247
  %249 = zext i1 %248 to i8
  %250 = icmp ne i8 %249, 0
  %load_PipeTemp203 = load i16, ptr %PipeTemp, align 2
  %251 = sext i16 %load_PipeTemp203 to i32
  %tmpVar204 = icmp sgt i32 %251, 87
  %252 = zext i1 %tmpVar204 to i8
  %253 = icmp ne i8 %252, 0
  %254 = or i1 %250, %253
  %255 = zext i1 %254 to i8
  %256 = icmp ne i8 %255, 0
  br i1 %256, label %condition_body205, label %continue196

else191:                                          ; preds = %else169
  %load_FillHead215 = load i16, ptr %FillHead, align 2
  %257 = sext i16 %load_FillHead215 to i32
  %tmpVar216 = icmp slt i32 %257, 32
  %258 = zext i1 %tmpVar216 to i8
  %259 = icmp ne i8 %258, 0
  br i1 %259, label %condition_body217, label %else213

continue192:                                      ; preds = %continue214, %continue196
  br label %continue170

condition_body205:                                ; preds = %condition_body195
  %load_FillHead208 = load i16, ptr %FillHead, align 2
  %260 = sext i16 %load_FillHead208 to i32
  %tmpVar209 = icmp sgt i32 %260, 5
  %261 = zext i1 %tmpVar209 to i8
  %262 = icmp ne i8 %261, 0
  br i1 %262, label %condition_body210, label %else206

continue196:                                      ; preds = %continue207, %condition_body195
  br label %continue192

condition_body210:                                ; preds = %condition_body205
  %load_FillHead211 = load i16, ptr %FillHead, align 2
  %263 = sext i16 %load_FillHead211 to i32
  %tmpVar212 = sub i32 %263, 6
  %264 = trunc i32 %tmpVar212 to i16
  store i16 %264, ptr %FillHead, align 2
  br label %continue207

else206:                                          ; preds = %condition_body205
  store i16 0, ptr %FillHead, align 2
  br label %continue207

continue207:                                      ; preds = %else206, %condition_body210
  br label %continue196

condition_body217:                                ; preds = %else191
  %load_PVsum219 = load i16, ptr %PVsum, align 2
  %265 = sext i16 %load_PVsum219 to i32
  %tmpVar220 = icmp slt i32 %265, 55
  %266 = zext i1 %tmpVar220 to i8
  %267 = icmp ne i8 %266, 0
  %load_PVsum221 = load i16, ptr %PVsum, align 2
  %268 = sext i16 %load_PVsum221 to i32
  %tmpVar222 = icmp sgt i32 %268, 85
  %269 = zext i1 %tmpVar222 to i8
  %270 = icmp ne i8 %269, 0
  %271 = or i1 %267, %270
  %272 = zext i1 %271 to i8
  %273 = icmp ne i8 %272, 0
  %load_PipeTemp223 = load i16, ptr %PipeTemp, align 2
  %274 = sext i16 %load_PipeTemp223 to i32
  %tmpVar224 = icmp slt i32 %274, 65
  %275 = zext i1 %tmpVar224 to i8
  %276 = icmp ne i8 %275, 0
  %277 = or i1 %273, %276
  %278 = zext i1 %277 to i8
  %279 = icmp ne i8 %278, 0
  %load_PipeTemp225 = load i16, ptr %PipeTemp, align 2
  %280 = sext i16 %load_PipeTemp225 to i32
  %tmpVar226 = icmp sgt i32 %280, 80
  %281 = zext i1 %tmpVar226 to i8
  %282 = icmp ne i8 %281, 0
  %283 = or i1 %279, %282
  %284 = zext i1 %283 to i8
  %285 = icmp ne i8 %284, 0
  br i1 %285, label %condition_body227, label %continue218

else213:                                          ; preds = %else191
  %load_FillHead237 = load i16, ptr %FillHead, align 2
  %286 = sext i16 %load_FillHead237 to i32
  %tmpVar238 = icmp slt i32 %286, 40
  %287 = zext i1 %tmpVar238 to i8
  %288 = icmp ne i8 %287, 0
  br i1 %288, label %condition_body239, label %else235

continue214:                                      ; preds = %continue236, %continue218
  br label %continue192

condition_body227:                                ; preds = %condition_body217
  %load_FillHead230 = load i16, ptr %FillHead, align 2
  %289 = sext i16 %load_FillHead230 to i32
  %tmpVar231 = icmp sgt i32 %289, 5
  %290 = zext i1 %tmpVar231 to i8
  %291 = icmp ne i8 %290, 0
  br i1 %291, label %condition_body232, label %else228

continue218:                                      ; preds = %continue229, %condition_body217
  br label %continue214

condition_body232:                                ; preds = %condition_body227
  %load_FillHead233 = load i16, ptr %FillHead, align 2
  %292 = sext i16 %load_FillHead233 to i32
  %tmpVar234 = sub i32 %292, 6
  %293 = trunc i32 %tmpVar234 to i16
  store i16 %293, ptr %FillHead, align 2
  br label %continue229

else228:                                          ; preds = %condition_body227
  store i16 0, ptr %FillHead, align 2
  br label %continue229

continue229:                                      ; preds = %else228, %condition_body232
  br label %continue218

condition_body239:                                ; preds = %else213
  %load_PVsum241 = load i16, ptr %PVsum, align 2
  %294 = sext i16 %load_PVsum241 to i32
  %tmpVar242 = icmp slt i32 %294, 95
  %295 = zext i1 %tmpVar242 to i8
  %296 = icmp ne i8 %295, 0
  %load_PVsum243 = load i16, ptr %PVsum, align 2
  %297 = sext i16 %load_PVsum243 to i32
  %tmpVar244 = icmp sgt i32 %297, 125
  %298 = zext i1 %tmpVar244 to i8
  %299 = icmp ne i8 %298, 0
  %300 = or i1 %296, %299
  %301 = zext i1 %300 to i8
  %302 = icmp ne i8 %301, 0
  %load_PipeTemp245 = load i16, ptr %PipeTemp, align 2
  %303 = sext i16 %load_PipeTemp245 to i32
  %tmpVar246 = icmp slt i32 %303, 55
  %304 = zext i1 %tmpVar246 to i8
  %305 = icmp ne i8 %304, 0
  %306 = or i1 %302, %305
  %307 = zext i1 %306 to i8
  %308 = icmp ne i8 %307, 0
  %load_PipeTemp247 = load i16, ptr %PipeTemp, align 2
  %309 = sext i16 %load_PipeTemp247 to i32
  %tmpVar248 = icmp sgt i32 %309, 70
  %310 = zext i1 %tmpVar248 to i8
  %311 = icmp ne i8 %310, 0
  %312 = or i1 %308, %311
  %313 = zext i1 %312 to i8
  %314 = icmp ne i8 %313, 0
  br i1 %314, label %condition_body249, label %continue240

else235:                                          ; preds = %else213
  %load_FillHead259 = load i16, ptr %FillHead, align 2
  %315 = sext i16 %load_FillHead259 to i32
  %tmpVar260 = icmp slt i32 %315, 48
  %316 = zext i1 %tmpVar260 to i8
  %317 = icmp ne i8 %316, 0
  br i1 %317, label %condition_body261, label %else257

continue236:                                      ; preds = %continue258, %continue240
  br label %continue214

condition_body249:                                ; preds = %condition_body239
  %load_FillHead252 = load i16, ptr %FillHead, align 2
  %318 = sext i16 %load_FillHead252 to i32
  %tmpVar253 = icmp sgt i32 %318, 5
  %319 = zext i1 %tmpVar253 to i8
  %320 = icmp ne i8 %319, 0
  br i1 %320, label %condition_body254, label %else250

continue240:                                      ; preds = %continue251, %condition_body239
  br label %continue236

condition_body254:                                ; preds = %condition_body249
  %load_FillHead255 = load i16, ptr %FillHead, align 2
  %321 = sext i16 %load_FillHead255 to i32
  %tmpVar256 = sub i32 %321, 6
  %322 = trunc i32 %tmpVar256 to i16
  store i16 %322, ptr %FillHead, align 2
  br label %continue251

else250:                                          ; preds = %condition_body249
  store i16 0, ptr %FillHead, align 2
  br label %continue251

continue251:                                      ; preds = %else250, %condition_body254
  br label %continue240

condition_body261:                                ; preds = %else235
  %load_PVsum263 = load i16, ptr %PVsum, align 2
  %323 = sext i16 %load_PVsum263 to i32
  %tmpVar264 = icmp slt i32 %323, 65
  %324 = zext i1 %tmpVar264 to i8
  %325 = icmp ne i8 %324, 0
  %load_PVsum265 = load i16, ptr %PVsum, align 2
  %326 = sext i16 %load_PVsum265 to i32
  %tmpVar266 = icmp sgt i32 %326, 95
  %327 = zext i1 %tmpVar266 to i8
  %328 = icmp ne i8 %327, 0
  %329 = or i1 %325, %328
  %330 = zext i1 %329 to i8
  %331 = icmp ne i8 %330, 0
  %load_PipeTemp267 = load i16, ptr %PipeTemp, align 2
  %332 = sext i16 %load_PipeTemp267 to i32
  %tmpVar268 = icmp slt i32 %332, 78
  %333 = zext i1 %tmpVar268 to i8
  %334 = icmp ne i8 %333, 0
  %335 = or i1 %331, %334
  %336 = zext i1 %335 to i8
  %337 = icmp ne i8 %336, 0
  %load_PipeTemp269 = load i16, ptr %PipeTemp, align 2
  %338 = sext i16 %load_PipeTemp269 to i32
  %tmpVar270 = icmp sgt i32 %338, 93
  %339 = zext i1 %tmpVar270 to i8
  %340 = icmp ne i8 %339, 0
  %341 = or i1 %337, %340
  %342 = zext i1 %341 to i8
  %343 = icmp ne i8 %342, 0
  br i1 %343, label %condition_body271, label %continue262

else257:                                          ; preds = %else235
  %load_FillHead281 = load i16, ptr %FillHead, align 2
  %344 = sext i16 %load_FillHead281 to i32
  %tmpVar282 = icmp slt i32 %344, 56
  %345 = zext i1 %tmpVar282 to i8
  %346 = icmp ne i8 %345, 0
  br i1 %346, label %condition_body283, label %else279

continue258:                                      ; preds = %continue280, %continue262
  br label %continue236

condition_body271:                                ; preds = %condition_body261
  %load_FillHead274 = load i16, ptr %FillHead, align 2
  %347 = sext i16 %load_FillHead274 to i32
  %tmpVar275 = icmp sgt i32 %347, 5
  %348 = zext i1 %tmpVar275 to i8
  %349 = icmp ne i8 %348, 0
  br i1 %349, label %condition_body276, label %else272

continue262:                                      ; preds = %continue273, %condition_body261
  br label %continue258

condition_body276:                                ; preds = %condition_body271
  %load_FillHead277 = load i16, ptr %FillHead, align 2
  %350 = sext i16 %load_FillHead277 to i32
  %tmpVar278 = sub i32 %350, 6
  %351 = trunc i32 %tmpVar278 to i16
  store i16 %351, ptr %FillHead, align 2
  br label %continue273

else272:                                          ; preds = %condition_body271
  store i16 0, ptr %FillHead, align 2
  br label %continue273

continue273:                                      ; preds = %else272, %condition_body276
  br label %continue262

condition_body283:                                ; preds = %else257
  %load_PVsum285 = load i16, ptr %PVsum, align 2
  %352 = sext i16 %load_PVsum285 to i32
  %tmpVar286 = icmp slt i32 %352, 85
  %353 = zext i1 %tmpVar286 to i8
  %354 = icmp ne i8 %353, 0
  %load_PVsum287 = load i16, ptr %PVsum, align 2
  %355 = sext i16 %load_PVsum287 to i32
  %tmpVar288 = icmp sgt i32 %355, 115
  %356 = zext i1 %tmpVar288 to i8
  %357 = icmp ne i8 %356, 0
  %358 = or i1 %354, %357
  %359 = zext i1 %358 to i8
  %360 = icmp ne i8 %359, 0
  %load_PipeTemp289 = load i16, ptr %PipeTemp, align 2
  %361 = sext i16 %load_PipeTemp289 to i32
  %tmpVar290 = icmp slt i32 %361, 52
  %362 = zext i1 %tmpVar290 to i8
  %363 = icmp ne i8 %362, 0
  %364 = or i1 %360, %363
  %365 = zext i1 %364 to i8
  %366 = icmp ne i8 %365, 0
  %load_PipeTemp291 = load i16, ptr %PipeTemp, align 2
  %367 = sext i16 %load_PipeTemp291 to i32
  %tmpVar292 = icmp sgt i32 %367, 67
  %368 = zext i1 %tmpVar292 to i8
  %369 = icmp ne i8 %368, 0
  %370 = or i1 %366, %369
  %371 = zext i1 %370 to i8
  %372 = icmp ne i8 %371, 0
  br i1 %372, label %condition_body293, label %continue284

else279:                                          ; preds = %else257
  %load_PVsum302 = load i16, ptr %PVsum, align 2
  %373 = sext i16 %load_PVsum302 to i32
  %tmpVar303 = icmp slt i32 %373, 75
  %374 = zext i1 %tmpVar303 to i8
  %375 = icmp ne i8 %374, 0
  %load_PVsum304 = load i16, ptr %PVsum, align 2
  %376 = sext i16 %load_PVsum304 to i32
  %tmpVar305 = icmp sgt i32 %376, 105
  %377 = zext i1 %tmpVar305 to i8
  %378 = icmp ne i8 %377, 0
  %379 = or i1 %375, %378
  %380 = zext i1 %379 to i8
  %381 = icmp ne i8 %380, 0
  %load_PipeTemp306 = load i16, ptr %PipeTemp, align 2
  %382 = sext i16 %load_PipeTemp306 to i32
  %tmpVar307 = icmp slt i32 %382, 63
  %383 = zext i1 %tmpVar307 to i8
  %384 = icmp ne i8 %383, 0
  %385 = or i1 %381, %384
  %386 = zext i1 %385 to i8
  %387 = icmp ne i8 %386, 0
  %load_PipeTemp308 = load i16, ptr %PipeTemp, align 2
  %388 = sext i16 %load_PipeTemp308 to i32
  %tmpVar309 = icmp sgt i32 %388, 78
  %389 = zext i1 %tmpVar309 to i8
  %390 = icmp ne i8 %389, 0
  %391 = or i1 %387, %390
  %392 = zext i1 %391 to i8
  %393 = icmp ne i8 %392, 0
  br i1 %393, label %condition_body310, label %continue301

continue280:                                      ; preds = %continue301, %continue284
  br label %continue258

condition_body293:                                ; preds = %condition_body283
  %load_FillHead296 = load i16, ptr %FillHead, align 2
  %394 = sext i16 %load_FillHead296 to i32
  %tmpVar297 = icmp sgt i32 %394, 5
  %395 = zext i1 %tmpVar297 to i8
  %396 = icmp ne i8 %395, 0
  br i1 %396, label %condition_body298, label %else294

continue284:                                      ; preds = %continue295, %condition_body283
  br label %continue280

condition_body298:                                ; preds = %condition_body293
  %load_FillHead299 = load i16, ptr %FillHead, align 2
  %397 = sext i16 %load_FillHead299 to i32
  %tmpVar300 = sub i32 %397, 6
  %398 = trunc i32 %tmpVar300 to i16
  store i16 %398, ptr %FillHead, align 2
  br label %continue295

else294:                                          ; preds = %condition_body293
  store i16 0, ptr %FillHead, align 2
  br label %continue295

continue295:                                      ; preds = %else294, %condition_body298
  br label %continue284

condition_body310:                                ; preds = %else279
  %load_FillHead313 = load i16, ptr %FillHead, align 2
  %399 = sext i16 %load_FillHead313 to i32
  %tmpVar314 = icmp sgt i32 %399, 5
  %400 = zext i1 %tmpVar314 to i8
  %401 = icmp ne i8 %400, 0
  br i1 %401, label %condition_body315, label %else311

continue301:                                      ; preds = %continue312, %else279
  br label %continue280

condition_body315:                                ; preds = %condition_body310
  %load_FillHead316 = load i16, ptr %FillHead, align 2
  %402 = sext i16 %load_FillHead316 to i32
  %tmpVar317 = sub i32 %402, 6
  %403 = trunc i32 %tmpVar317 to i16
  store i16 %403, ptr %FillHead, align 2
  br label %continue312

else311:                                          ; preds = %condition_body310
  store i16 0, ptr %FillHead, align 2
  br label %continue312

continue312:                                      ; preds = %else311, %condition_body315
  br label %continue301
}

define void @PLC_PRG(ptr %0) {
entry:
  %PumpRate = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 0
  %ValvePos = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 1
  %PipeTemp = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 2
  %BackPressure = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 3
  %FeedConc = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 4
  %CoolantRate = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 5
  %Cmd = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 6
  %Ctrl = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 7
  %1 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 1
  %load_PumpRate = load i16, ptr %PumpRate, align 2
  store i16 %load_PumpRate, ptr %1, align 2
  %2 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 2
  %load_ValvePos = load i16, ptr %ValvePos, align 2
  store i16 %load_ValvePos, ptr %2, align 2
  %3 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 3
  %load_PipeTemp = load i16, ptr %PipeTemp, align 2
  store i16 %load_PipeTemp, ptr %3, align 2
  %4 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 4
  %load_BackPressure = load i16, ptr %BackPressure, align 2
  store i16 %load_BackPressure, ptr %4, align 2
  %5 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 5
  %load_FeedConc = load i16, ptr %FeedConc, align 2
  store i16 %load_FeedConc, ptr %5, align 2
  %6 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 6
  %load_CoolantRate = load i16, ptr %CoolantRate, align 2
  store i16 %load_CoolantRate, ptr %6, align 2
  %7 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 7
  %load_Cmd = load i8, ptr %Cmd, align 1
  store i8 %load_Cmd, ptr %7, align 1
  call void @PipelineCtrl(ptr %Ctrl)
  ret void
}

define void @PLC_PRG__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8
  store ptr %0, ptr %self, align 8
  %deref = load ptr, ptr %self, align 8
  %PumpRate = getelementptr inbounds nuw %PLC_PRG, ptr %deref, i32 0, i32 0
  store i16 0, ptr %PumpRate, align 2
  %deref1 = load ptr, ptr %self, align 8
  %ValvePos = getelementptr inbounds nuw %PLC_PRG, ptr %deref1, i32 0, i32 1
  store i16 0, ptr %ValvePos, align 2
  %deref2 = load ptr, ptr %self, align 8
  %PipeTemp = getelementptr inbounds nuw %PLC_PRG, ptr %deref2, i32 0, i32 2
  store i16 0, ptr %PipeTemp, align 2
  %deref3 = load ptr, ptr %self, align 8
  %BackPressure = getelementptr inbounds nuw %PLC_PRG, ptr %deref3, i32 0, i32 3
  store i16 0, ptr %BackPressure, align 2
  %deref4 = load ptr, ptr %self, align 8
  %FeedConc = getelementptr inbounds nuw %PLC_PRG, ptr %deref4, i32 0, i32 4
  store i16 0, ptr %FeedConc, align 2
  %deref5 = load ptr, ptr %self, align 8
  %CoolantRate = getelementptr inbounds nuw %PLC_PRG, ptr %deref5, i32 0, i32 5
  store i16 0, ptr %CoolantRate, align 2
  %deref6 = load ptr, ptr %self, align 8
  %Cmd = getelementptr inbounds nuw %PLC_PRG, ptr %deref6, i32 0, i32 6
  store i8 0, ptr %Cmd, align 1
  %deref7 = load ptr, ptr %self, align 8
  %Ctrl = getelementptr inbounds nuw %PLC_PRG, ptr %deref7, i32 0, i32 7
  call void @PipelineCtrl__ctor(ptr %Ctrl)
  ret void
}

define void @PipelineCtrl__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8
  store ptr %0, ptr %self, align 8
  %deref = load ptr, ptr %self, align 8
  %__vtable = getelementptr inbounds nuw %PipelineCtrl, ptr %deref, i32 0, i32 0
  call void @__PipelineCtrl___vtable__ctor(ptr %__vtable)
  %deref1 = load ptr, ptr %self, align 8
  %Phase = getelementptr inbounds nuw %PipelineCtrl, ptr %deref1, i32 0, i32 9
  store i8 0, ptr %Phase, align 1
  %deref2 = load ptr, ptr %self, align 8
  %CycleCount = getelementptr inbounds nuw %PipelineCtrl, ptr %deref2, i32 0, i32 10
  store i16 0, ptr %CycleCount, align 2
  %deref3 = load ptr, ptr %self, align 8
  %PrimeCycles = getelementptr inbounds nuw %PipelineCtrl, ptr %deref3, i32 0, i32 11
  store i16 0, ptr %PrimeCycles, align 2
  %deref4 = load ptr, ptr %self, align 8
  %PrimeScore = getelementptr inbounds nuw %PipelineCtrl, ptr %deref4, i32 0, i32 12
  store i16 0, ptr %PrimeScore, align 2
  %deref5 = load ptr, ptr %self, align 8
  %FluxScore = getelementptr inbounds nuw %PipelineCtrl, ptr %deref5, i32 0, i32 13
  store i16 0, ptr %FluxScore, align 2
  %deref6 = load ptr, ptr %self, align 8
  %FluxSum = getelementptr inbounds nuw %PipelineCtrl, ptr %deref6, i32 0, i32 14
  store i16 0, ptr %FluxSum, align 2
  %deref7 = load ptr, ptr %self, align 8
  %FlowAccum = getelementptr inbounds nuw %PipelineCtrl, ptr %deref7, i32 0, i32 15
  store i16 0, ptr %FlowAccum, align 2
  %deref8 = load ptr, ptr %self, align 8
  %PressAccum = getelementptr inbounds nuw %PipelineCtrl, ptr %deref8, i32 0, i32 16
  store i16 0, ptr %PressAccum, align 2
  %deref9 = load ptr, ptr %self, align 8
  %TempAccum = getelementptr inbounds nuw %PipelineCtrl, ptr %deref9, i32 0, i32 17
  store i16 0, ptr %TempAccum, align 2
  %deref10 = load ptr, ptr %self, align 8
  %PhaseCounter = getelementptr inbounds nuw %PipelineCtrl, ptr %deref10, i32 0, i32 18
  store i16 0, ptr %PhaseCounter, align 2
  %deref11 = load ptr, ptr %self, align 8
  %FillHead = getelementptr inbounds nuw %PipelineCtrl, ptr %deref11, i32 0, i32 19
  store i16 0, ptr %FillHead, align 2
  %deref12 = load ptr, ptr %self, align 8
  %Buffer = getelementptr inbounds nuw %PipelineCtrl, ptr %deref12, i32 0, i32 20
  call void @__PipelineCtrl_Buffer__ctor(ptr %Buffer)
  %deref13 = load ptr, ptr %self, align 8
  %PVsum = getelementptr inbounds nuw %PipelineCtrl, ptr %deref13, i32 0, i32 21
  store i16 0, ptr %PVsum, align 2
  %deref14 = load ptr, ptr %self, align 8
  %__vtable15 = getelementptr inbounds nuw %PipelineCtrl, ptr %deref14, i32 0, i32 0
  store ptr @__vtable_PipelineCtrl_instance, ptr %__vtable15, align 8
  ret void
}

define void @__PipelineCtrl_Buffer__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8
  store ptr %0, ptr %self, align 8
  ret void
}

define void @__vtable_PipelineCtrl__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8
  store ptr %0, ptr %self, align 8
  %deref = load ptr, ptr %self, align 8
  %__body = getelementptr inbounds nuw %__vtable_PipelineCtrl, ptr %deref, i32 0, i32 0
  call void @____vtable_PipelineCtrl___body__ctor(ptr %__body)
  %deref1 = load ptr, ptr %self, align 8
  %__body2 = getelementptr inbounds nuw %__vtable_PipelineCtrl, ptr %deref1, i32 0, i32 0
  store ptr @PipelineCtrl, ptr %__body2, align 8
  ret void
}

define void @__PipelineCtrl___vtable__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8
  store ptr %0, ptr %self, align 8
  ret void
}

define void @____vtable_PipelineCtrl___body__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8
  store ptr %0, ptr %self, align 8
  ret void
}

define void @__unit_pipeline_controller_st__ctor() {
entry:
  call void @__vtable_PipelineCtrl__ctor(ptr @__vtable_PipelineCtrl_instance)
  call void @PLC_PRG__ctor(ptr @PLC_PRG_instance)
  ret void
}
