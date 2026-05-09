; ModuleID = '/var/folders/c5/lhctbtjn68s2kmm80z67rllc0000gn/T/.tmpWX97XC/icsquartz/benchmarks/pipeline_controller/src/program.st.ll'
source_filename = "/Users/hamza/Documents/NYUAD/2026_Spring/DirectedStudies/StateFuzzer/rusty/icsquartz/benchmarks/pipeline_controller/src/program.st"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-darwin25.3.0"

%__vtable_PipelineCtrl = type { ptr }
%PLC_PRG = type { i16, i16, i16, i16, i16, i16, i8, %PipelineCtrl }
%PipelineCtrl = type { ptr, i16, i16, i16, i16, i16, i16, i8, i8, i8, i16, i16, i16, i16, i16, i16, i16, i16, i16, i16, [64 x i16], i16, i16 }

@PHASE_IDLE = unnamed_addr constant i8 0
@PHASE_PRIME = unnamed_addr constant i8 1
@PHASE_FLOW = unnamed_addr constant i8 2
@PHASE_FILL = unnamed_addr constant i8 3
@__vtable_PipelineCtrl_instance = global %__vtable_PipelineCtrl zeroinitializer
@PLC_PRG_instance = global %PLC_PRG zeroinitializer
@llvm.global_ctors = appending global [1 x { i32, ptr, ptr }] [{ i32, ptr, ptr } { i32 65535, ptr @__unit_program_st__ctor, ptr null }]

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
  switch i8 %load_Phase, label %else [
    i8 0, label %case
    i8 1, label %case8
    i8 2, label %case37
    i8 3, label %case69
  ]

case:                                             ; preds = %entry
  %load_Cmd = load i8, ptr %Cmd, align 1
  %3 = sext i8 %load_Cmd to i32
  %tmpVar2 = icmp eq i32 %3, 1
  %4 = zext i1 %tmpVar2 to i8
  %5 = icmp ne i8 %4, 0
  br i1 %5, label %condition_body, label %continue1

case8:                                            ; preds = %entry
  %load_PrimeCycles = load i16, ptr %PrimeCycles, align 2
  %6 = sext i16 %load_PrimeCycles to i32
  %tmpVar9 = add i32 %6, 1
  %7 = trunc i32 %tmpVar9 to i16
  store i16 %7, ptr %PrimeCycles, align 2
  %load_PumpRate = load i16, ptr %PumpRate, align 2
  %8 = sext i16 %load_PumpRate to i32
  %load_BackPressure = load i16, ptr %BackPressure, align 2
  %9 = sext i16 %load_BackPressure to i32
  %tmpVar10 = add i32 %8, %9
  %10 = trunc i32 %tmpVar10 to i16
  store i16 %10, ptr %PVsum, align 2
  %load_PrimeCycles12 = load i16, ptr %PrimeCycles, align 2
  %11 = sext i16 %load_PrimeCycles12 to i32
  %tmpVar13 = srem i32 %11, 3
  %tmpVar14 = icmp eq i32 %tmpVar13, 0
  %12 = zext i1 %tmpVar14 to i8
  %13 = icmp ne i8 %12, 0
  br i1 %13, label %condition_body15, label %continue11

case37:                                           ; preds = %entry
  %load_PipeTemp = load i16, ptr %PipeTemp, align 2
  %14 = sext i16 %load_PipeTemp to i32
  %load_CoolantRate = load i16, ptr %CoolantRate, align 2
  %15 = sext i16 %load_CoolantRate to i32
  %tmpVar38 = add i32 %14, %15
  %16 = trunc i32 %tmpVar38 to i16
  store i16 %16, ptr %FluxSum, align 2
  %load_FluxSum = load i16, ptr %FluxSum, align 2
  %17 = sext i16 %load_FluxSum to i32
  %tmpVar41 = icmp sge i32 %17, 80
  %18 = zext i1 %tmpVar41 to i8
  %19 = icmp ne i8 %18, 0
  br i1 %19, label %78, label %82

case69:                                           ; preds = %entry
  %load_PhaseCounter = load i16, ptr %PhaseCounter, align 2
  %20 = sext i16 %load_PhaseCounter to i32
  %tmpVar70 = add i32 %20, 1
  %21 = trunc i32 %tmpVar70 to i16
  store i16 %21, ptr %PhaseCounter, align 2
  %load_PumpRate73 = load i16, ptr %PumpRate, align 2
  %22 = sext i16 %load_PumpRate73 to i32
  %tmpVar74 = icmp sge i32 %22, 40
  %23 = zext i1 %tmpVar74 to i8
  %24 = icmp ne i8 %23, 0
  br i1 %24, label %125, label %129

else:                                             ; preds = %entry
  br label %continue

continue:                                         ; preds = %continue138, %continue65, %continue33, %continue1, %else
  %load_Phase301 = load i8, ptr %Phase, align 1
  store i8 %load_Phase301, ptr %Status, align 1
  ret void

condition_body:                                   ; preds = %case
  store i16 0, ptr %i, align 2
  br i1 true, label %predicate_sle, label %predicate_sge

continue1:                                        ; preds = %continue3, %case
  br label %continue

predicate_sle:                                    ; preds = %increment, %condition_body
  %25 = load i16, ptr %i, align 2
  %26 = sext i16 %25 to i32
  %condition = icmp sle i32 %26, 63
  br i1 %condition, label %loop, label %continue3

predicate_sge:                                    ; preds = %increment, %condition_body
  %27 = load i16, ptr %i, align 2
  %28 = sext i16 %27 to i32
  %condition4 = icmp sge i32 %28, 63
  br i1 %condition4, label %loop, label %continue3

loop:                                             ; preds = %predicate_sge, %predicate_sle
  %load_i = load i16, ptr %i, align 2
  %29 = sext i16 %load_i to i32
  %tmpVar5 = mul i32 1, %29
  %tmpVar6 = add i32 %tmpVar5, 0
  %tmpVar7 = getelementptr inbounds [64 x i16], ptr %Buffer, i32 0, i32 %tmpVar6
  store i16 0, ptr %tmpVar7, align 2
  br label %increment

increment:                                        ; preds = %loop
  %30 = load i16, ptr %i, align 2
  %31 = sext i16 %30 to i32
  %next = add i32 1, %31
  %32 = trunc i32 %next to i16
  store i16 %32, ptr %i, align 2
  br i1 true, label %predicate_sle, label %predicate_sge

continue3:                                        ; preds = %predicate_sge, %predicate_sle
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

condition_body15:                                 ; preds = %case8
  %load_PVsum = load i16, ptr %PVsum, align 2
  %33 = sext i16 %load_PVsum to i32
  %tmpVar18 = icmp sge i32 %33, 80
  %34 = zext i1 %tmpVar18 to i8
  %35 = icmp ne i8 %34, 0
  br i1 %35, label %44, label %48

continue11:                                       ; preds = %continue17, %case8
  %load_PrimeScore34 = load i16, ptr %PrimeScore, align 2
  %36 = sext i16 %load_PrimeScore34 to i32
  %tmpVar35 = icmp sge i32 %36, 8
  %37 = zext i1 %tmpVar35 to i8
  %38 = icmp ne i8 %37, 0
  br i1 %38, label %condition_body36, label %continue33

condition_body24:                                 ; preds = %64
  %load_PrimeScore = load i16, ptr %PrimeScore, align 2
  %39 = sext i16 %load_PrimeScore to i32
  %tmpVar25 = add i32 %39, 1
  %40 = trunc i32 %tmpVar25 to i16
  store i16 %40, ptr %PrimeScore, align 2
  br label %continue17

else16:                                           ; preds = %64
  %load_PrimeScore28 = load i16, ptr %PrimeScore, align 2
  %41 = sext i16 %load_PrimeScore28 to i32
  %tmpVar29 = icmp sgt i32 %41, 1
  %42 = zext i1 %tmpVar29 to i8
  %43 = icmp ne i8 %42, 0
  br i1 %43, label %condition_body30, label %else26

continue17:                                       ; preds = %continue27, %condition_body24
  br label %continue11

44:                                               ; preds = %condition_body15
  %load_PVsum19 = load i16, ptr %PVsum, align 2
  %45 = sext i16 %load_PVsum19 to i32
  %tmpVar20 = icmp sle i32 %45, 160
  %46 = zext i1 %tmpVar20 to i8
  %47 = icmp ne i8 %46, 0
  br label %48

48:                                               ; preds = %44, %condition_body15
  %49 = phi i1 [ %35, %condition_body15 ], [ %47, %44 ]
  %50 = zext i1 %49 to i8
  %51 = icmp ne i8 %50, 0
  br i1 %51, label %52, label %56

52:                                               ; preds = %48
  %load_ValvePos = load i16, ptr %ValvePos, align 2
  %53 = sext i16 %load_ValvePos to i32
  %tmpVar21 = icmp sge i32 %53, 15
  %54 = zext i1 %tmpVar21 to i8
  %55 = icmp ne i8 %54, 0
  br label %56

56:                                               ; preds = %52, %48
  %57 = phi i1 [ %51, %48 ], [ %55, %52 ]
  %58 = zext i1 %57 to i8
  %59 = icmp ne i8 %58, 0
  br i1 %59, label %60, label %64

60:                                               ; preds = %56
  %load_ValvePos22 = load i16, ptr %ValvePos, align 2
  %61 = sext i16 %load_ValvePos22 to i32
  %tmpVar23 = icmp sle i32 %61, 60
  %62 = zext i1 %tmpVar23 to i8
  %63 = icmp ne i8 %62, 0
  br label %64

64:                                               ; preds = %60, %56
  %65 = phi i1 [ %59, %56 ], [ %63, %60 ]
  %66 = zext i1 %65 to i8
  %67 = icmp ne i8 %66, 0
  br i1 %67, label %condition_body24, label %else16

condition_body30:                                 ; preds = %else16
  %load_PrimeScore31 = load i16, ptr %PrimeScore, align 2
  %68 = sext i16 %load_PrimeScore31 to i32
  %tmpVar32 = sub i32 %68, 2
  %69 = trunc i32 %tmpVar32 to i16
  store i16 %69, ptr %PrimeScore, align 2
  br label %continue27

else26:                                           ; preds = %else16
  store i16 0, ptr %PrimeScore, align 2
  br label %continue27

continue27:                                       ; preds = %else26, %condition_body30
  br label %continue17

condition_body36:                                 ; preds = %continue11
  store i8 2, ptr %Phase, align 1
  br label %continue33

continue33:                                       ; preds = %condition_body36, %continue11
  br label %continue

condition_body47:                                 ; preds = %98
  %load_FluxScore = load i16, ptr %FluxScore, align 2
  %70 = sext i16 %load_FluxScore to i32
  %tmpVar48 = add i32 %70, 1
  %71 = trunc i32 %tmpVar48 to i16
  store i16 %71, ptr %FluxScore, align 2
  br label %continue40

else39:                                           ; preds = %98
  %load_FluxScore51 = load i16, ptr %FluxScore, align 2
  %72 = sext i16 %load_FluxScore51 to i32
  %tmpVar52 = icmp sgt i32 %72, 1
  %73 = zext i1 %tmpVar52 to i8
  %74 = icmp ne i8 %73, 0
  br i1 %74, label %condition_body53, label %else49

continue40:                                       ; preds = %continue50, %condition_body47
  %load_CycleCount57 = load i16, ptr %CycleCount, align 2
  %75 = sext i16 %load_CycleCount57 to i32
  %tmpVar58 = srem i32 %75, 11
  %tmpVar59 = icmp eq i32 %tmpVar58, 0
  %76 = zext i1 %tmpVar59 to i8
  %77 = icmp ne i8 %76, 0
  br i1 %77, label %109, label %113

78:                                               ; preds = %case37
  %load_FluxSum42 = load i16, ptr %FluxSum, align 2
  %79 = sext i16 %load_FluxSum42 to i32
  %tmpVar43 = icmp sle i32 %79, 160
  %80 = zext i1 %tmpVar43 to i8
  %81 = icmp ne i8 %80, 0
  br label %82

82:                                               ; preds = %78, %case37
  %83 = phi i1 [ %19, %case37 ], [ %81, %78 ]
  %84 = zext i1 %83 to i8
  %85 = icmp ne i8 %84, 0
  br i1 %85, label %86, label %90

86:                                               ; preds = %82
  %load_FeedConc = load i16, ptr %FeedConc, align 2
  %87 = sext i16 %load_FeedConc to i32
  %tmpVar44 = icmp sge i32 %87, 20
  %88 = zext i1 %tmpVar44 to i8
  %89 = icmp ne i8 %88, 0
  br label %90

90:                                               ; preds = %86, %82
  %91 = phi i1 [ %85, %82 ], [ %89, %86 ]
  %92 = zext i1 %91 to i8
  %93 = icmp ne i8 %92, 0
  br i1 %93, label %94, label %98

94:                                               ; preds = %90
  %load_FeedConc45 = load i16, ptr %FeedConc, align 2
  %95 = sext i16 %load_FeedConc45 to i32
  %tmpVar46 = icmp sle i32 %95, 70
  %96 = zext i1 %tmpVar46 to i8
  %97 = icmp ne i8 %96, 0
  br label %98

98:                                               ; preds = %94, %90
  %99 = phi i1 [ %93, %90 ], [ %97, %94 ]
  %100 = zext i1 %99 to i8
  %101 = icmp ne i8 %100, 0
  br i1 %101, label %condition_body47, label %else39

condition_body53:                                 ; preds = %else39
  %load_FluxScore54 = load i16, ptr %FluxScore, align 2
  %102 = sext i16 %load_FluxScore54 to i32
  %tmpVar55 = sub i32 %102, 2
  %103 = trunc i32 %tmpVar55 to i16
  store i16 %103, ptr %FluxScore, align 2
  br label %continue50

else49:                                           ; preds = %else39
  store i16 0, ptr %FluxScore, align 2
  br label %continue50

continue50:                                       ; preds = %else49, %condition_body53
  br label %continue40

condition_body62:                                 ; preds = %113
  %load_FluxScore63 = load i16, ptr %FluxScore, align 2
  %104 = sext i16 %load_FluxScore63 to i32
  %tmpVar64 = sdiv i32 %104, 2
  %105 = trunc i32 %tmpVar64 to i16
  store i16 %105, ptr %FluxScore, align 2
  br label %continue56

continue56:                                       ; preds = %113, %condition_body62
  %load_FluxScore66 = load i16, ptr %FluxScore, align 2
  %106 = sext i16 %load_FluxScore66 to i32
  %tmpVar67 = icmp sge i32 %106, 8
  %107 = zext i1 %tmpVar67 to i8
  %108 = icmp ne i8 %107, 0
  br i1 %108, label %condition_body68, label %continue65

109:                                              ; preds = %continue40
  %load_FluxScore60 = load i16, ptr %FluxScore, align 2
  %110 = sext i16 %load_FluxScore60 to i32
  %tmpVar61 = icmp sgt i32 %110, 0
  %111 = zext i1 %tmpVar61 to i8
  %112 = icmp ne i8 %111, 0
  br label %113

113:                                              ; preds = %109, %continue40
  %114 = phi i1 [ %77, %continue40 ], [ %112, %109 ]
  %115 = zext i1 %114 to i8
  %116 = icmp ne i8 %115, 0
  br i1 %116, label %condition_body62, label %continue56

condition_body68:                                 ; preds = %continue56
  store i8 3, ptr %Phase, align 1
  br label %continue65

continue65:                                       ; preds = %condition_body68, %continue56
  br label %continue

condition_body77:                                 ; preds = %129
  %load_FlowAccum = load i16, ptr %FlowAccum, align 2
  %117 = sext i16 %load_FlowAccum to i32
  %tmpVar78 = add i32 %117, 1
  %118 = trunc i32 %tmpVar78 to i16
  store i16 %118, ptr %FlowAccum, align 2
  br label %continue72

else71:                                           ; preds = %129
  %load_FlowAccum81 = load i16, ptr %FlowAccum, align 2
  %119 = sext i16 %load_FlowAccum81 to i32
  %tmpVar82 = icmp sgt i32 %119, 1
  %120 = zext i1 %tmpVar82 to i8
  %121 = icmp ne i8 %120, 0
  br i1 %121, label %condition_body83, label %else79

continue72:                                       ; preds = %continue80, %condition_body77
  %load_BackPressure88 = load i16, ptr %BackPressure, align 2
  %122 = sext i16 %load_BackPressure88 to i32
  %tmpVar89 = icmp sge i32 %122, 30
  %123 = zext i1 %tmpVar89 to i8
  %124 = icmp ne i8 %123, 0
  br i1 %124, label %143, label %147

125:                                              ; preds = %case69
  %load_PumpRate75 = load i16, ptr %PumpRate, align 2
  %126 = sext i16 %load_PumpRate75 to i32
  %tmpVar76 = icmp sle i32 %126, 90
  %127 = zext i1 %tmpVar76 to i8
  %128 = icmp ne i8 %127, 0
  br label %129

129:                                              ; preds = %125, %case69
  %130 = phi i1 [ %24, %case69 ], [ %128, %125 ]
  %131 = zext i1 %130 to i8
  %132 = icmp ne i8 %131, 0
  br i1 %132, label %condition_body77, label %else71

condition_body83:                                 ; preds = %else71
  %load_FlowAccum84 = load i16, ptr %FlowAccum, align 2
  %133 = sext i16 %load_FlowAccum84 to i32
  %tmpVar85 = sub i32 %133, 2
  %134 = trunc i32 %tmpVar85 to i16
  store i16 %134, ptr %FlowAccum, align 2
  br label %continue80

else79:                                           ; preds = %else71
  store i16 0, ptr %FlowAccum, align 2
  br label %continue80

continue80:                                       ; preds = %else79, %condition_body83
  br label %continue72

condition_body92:                                 ; preds = %147
  %load_PressAccum = load i16, ptr %PressAccum, align 2
  %135 = sext i16 %load_PressAccum to i32
  %tmpVar93 = add i32 %135, 1
  %136 = trunc i32 %tmpVar93 to i16
  store i16 %136, ptr %PressAccum, align 2
  br label %continue87

else86:                                           ; preds = %147
  %load_PressAccum95 = load i16, ptr %PressAccum, align 2
  %137 = sext i16 %load_PressAccum95 to i32
  %tmpVar96 = icmp sgt i32 %137, 0
  %138 = zext i1 %tmpVar96 to i8
  %139 = icmp ne i8 %138, 0
  br i1 %139, label %condition_body97, label %continue94

continue87:                                       ; preds = %continue94, %condition_body92
  %load_PipeTemp102 = load i16, ptr %PipeTemp, align 2
  %140 = sext i16 %load_PipeTemp102 to i32
  %tmpVar103 = icmp sge i32 %140, 50
  %141 = zext i1 %tmpVar103 to i8
  %142 = icmp ne i8 %141, 0
  br i1 %142, label %161, label %165

143:                                              ; preds = %continue72
  %load_BackPressure90 = load i16, ptr %BackPressure, align 2
  %144 = sext i16 %load_BackPressure90 to i32
  %tmpVar91 = icmp sle i32 %144, 80
  %145 = zext i1 %tmpVar91 to i8
  %146 = icmp ne i8 %145, 0
  br label %147

147:                                              ; preds = %143, %continue72
  %148 = phi i1 [ %124, %continue72 ], [ %146, %143 ]
  %149 = zext i1 %148 to i8
  %150 = icmp ne i8 %149, 0
  br i1 %150, label %condition_body92, label %else86

condition_body97:                                 ; preds = %else86
  %load_PressAccum98 = load i16, ptr %PressAccum, align 2
  %151 = sext i16 %load_PressAccum98 to i32
  %tmpVar99 = sub i32 %151, 1
  %152 = trunc i32 %tmpVar99 to i16
  store i16 %152, ptr %PressAccum, align 2
  br label %continue94

continue94:                                       ; preds = %condition_body97, %else86
  br label %continue87

condition_body106:                                ; preds = %165
  %load_TempAccum = load i16, ptr %TempAccum, align 2
  %153 = sext i16 %load_TempAccum to i32
  %tmpVar107 = add i32 %153, 1
  %154 = trunc i32 %tmpVar107 to i16
  store i16 %154, ptr %TempAccum, align 2
  br label %continue101

else100:                                          ; preds = %165
  %load_TempAccum110 = load i16, ptr %TempAccum, align 2
  %155 = sext i16 %load_TempAccum110 to i32
  %tmpVar111 = icmp sgt i32 %155, 1
  %156 = zext i1 %tmpVar111 to i8
  %157 = icmp ne i8 %156, 0
  br i1 %157, label %condition_body112, label %else108

continue101:                                      ; preds = %continue109, %condition_body106
  %load_FlowAccum116 = load i16, ptr %FlowAccum, align 2
  %158 = sext i16 %load_FlowAccum116 to i32
  %tmpVar117 = icmp sgt i32 %158, 6
  %159 = zext i1 %tmpVar117 to i8
  %160 = icmp ne i8 %159, 0
  br i1 %160, label %180, label %184

161:                                              ; preds = %continue87
  %load_PipeTemp104 = load i16, ptr %PipeTemp, align 2
  %162 = sext i16 %load_PipeTemp104 to i32
  %tmpVar105 = icmp sle i32 %162, 100
  %163 = zext i1 %tmpVar105 to i8
  %164 = icmp ne i8 %163, 0
  br label %165

165:                                              ; preds = %161, %continue87
  %166 = phi i1 [ %142, %continue87 ], [ %164, %161 ]
  %167 = zext i1 %166 to i8
  %168 = icmp ne i8 %167, 0
  br i1 %168, label %condition_body106, label %else100

condition_body112:                                ; preds = %else100
  %load_TempAccum113 = load i16, ptr %TempAccum, align 2
  %169 = sext i16 %load_TempAccum113 to i32
  %tmpVar114 = sub i32 %169, 2
  %170 = trunc i32 %tmpVar114 to i16
  store i16 %170, ptr %TempAccum, align 2
  br label %continue109

else108:                                          ; preds = %else100
  store i16 0, ptr %TempAccum, align 2
  br label %continue109

continue109:                                      ; preds = %else108, %condition_body112
  br label %continue101

condition_body122:                                ; preds = %192
  %load_PhaseCounter124 = load i16, ptr %PhaseCounter, align 2
  %171 = sext i16 %load_PhaseCounter124 to i32
  %tmpVar125 = srem i32 %171, 4
  %tmpVar126 = icmp eq i32 %tmpVar125, 0
  %172 = zext i1 %tmpVar126 to i8
  %173 = icmp ne i8 %172, 0
  br i1 %173, label %condition_body127, label %continue123

continue115:                                      ; preds = %continue123, %192
  %load_PumpRate129 = load i16, ptr %PumpRate, align 2
  %174 = sext i16 %load_PumpRate129 to i32
  %load_ValvePos130 = load i16, ptr %ValvePos, align 2
  %175 = sext i16 %load_ValvePos130 to i32
  %tmpVar131 = add i32 %174, %175
  %176 = trunc i32 %tmpVar131 to i16
  store i16 %176, ptr %PVsum, align 2
  %load_FillHead139 = load i16, ptr %FillHead, align 2
  %177 = sext i16 %load_FillHead139 to i32
  %tmpVar140 = icmp slt i32 %177, 8
  %178 = zext i1 %tmpVar140 to i8
  %179 = icmp ne i8 %178, 0
  br i1 %179, label %condition_body141, label %branch

180:                                              ; preds = %continue101
  %load_PressAccum118 = load i16, ptr %PressAccum, align 2
  %181 = sext i16 %load_PressAccum118 to i32
  %tmpVar119 = icmp sgt i32 %181, 5
  %182 = zext i1 %tmpVar119 to i8
  %183 = icmp ne i8 %182, 0
  br label %184

184:                                              ; preds = %180, %continue101
  %185 = phi i1 [ %160, %continue101 ], [ %183, %180 ]
  %186 = zext i1 %185 to i8
  %187 = icmp ne i8 %186, 0
  br i1 %187, label %188, label %192

188:                                              ; preds = %184
  %load_TempAccum120 = load i16, ptr %TempAccum, align 2
  %189 = sext i16 %load_TempAccum120 to i32
  %tmpVar121 = icmp sgt i32 %189, 6
  %190 = zext i1 %tmpVar121 to i8
  %191 = icmp ne i8 %190, 0
  br label %192

192:                                              ; preds = %188, %184
  %193 = phi i1 [ %187, %184 ], [ %191, %188 ]
  %194 = zext i1 %193 to i8
  %195 = icmp ne i8 %194, 0
  br i1 %195, label %condition_body122, label %continue115

condition_body127:                                ; preds = %condition_body122
  %load_FillHead = load i16, ptr %FillHead, align 2
  %196 = sext i16 %load_FillHead to i32
  %tmpVar128 = add i32 %196, 1
  %197 = trunc i32 %tmpVar128 to i16
  store i16 %197, ptr %FillHead, align 2
  br label %continue123

continue123:                                      ; preds = %condition_body127, %condition_body122
  br label %continue115

condition_body141:                                ; preds = %continue115
  %load_PVsum143 = load i16, ptr %PVsum, align 2
  %198 = sext i16 %load_PVsum143 to i32
  %tmpVar144 = icmp slt i32 %198, 60
  %199 = zext i1 %tmpVar144 to i8
  %200 = icmp ne i8 %199, 0
  br i1 %200, label %248, label %244

branch:                                           ; preds = %continue115
  %load_FillHead159 = load i16, ptr %FillHead, align 2
  %201 = sext i16 %load_FillHead159 to i32
  %tmpVar160 = icmp slt i32 %201, 16
  %202 = zext i1 %tmpVar160 to i8
  %203 = icmp ne i8 %202, 0
  br i1 %203, label %condition_body161, label %branch132

condition_body161:                                ; preds = %branch
  %load_PVsum163 = load i16, ptr %PVsum, align 2
  %204 = sext i16 %load_PVsum163 to i32
  %tmpVar164 = icmp slt i32 %204, 80
  %205 = zext i1 %tmpVar164 to i8
  %206 = icmp ne i8 %205, 0
  br i1 %206, label %277, label %273

branch132:                                        ; preds = %branch
  %load_FillHead179 = load i16, ptr %FillHead, align 2
  %207 = sext i16 %load_FillHead179 to i32
  %tmpVar180 = icmp slt i32 %207, 24
  %208 = zext i1 %tmpVar180 to i8
  %209 = icmp ne i8 %208, 0
  br i1 %209, label %condition_body181, label %branch133

condition_body181:                                ; preds = %branch132
  %load_PVsum183 = load i16, ptr %PVsum, align 2
  %210 = sext i16 %load_PVsum183 to i32
  %tmpVar184 = icmp slt i32 %210, 70
  %211 = zext i1 %tmpVar184 to i8
  %212 = icmp ne i8 %211, 0
  br i1 %212, label %306, label %302

branch133:                                        ; preds = %branch132
  %load_FillHead199 = load i16, ptr %FillHead, align 2
  %213 = sext i16 %load_FillHead199 to i32
  %tmpVar200 = icmp slt i32 %213, 32
  %214 = zext i1 %tmpVar200 to i8
  %215 = icmp ne i8 %214, 0
  br i1 %215, label %condition_body201, label %branch134

condition_body201:                                ; preds = %branch133
  %load_PVsum203 = load i16, ptr %PVsum, align 2
  %216 = sext i16 %load_PVsum203 to i32
  %tmpVar204 = icmp slt i32 %216, 55
  %217 = zext i1 %tmpVar204 to i8
  %218 = icmp ne i8 %217, 0
  br i1 %218, label %335, label %331

branch134:                                        ; preds = %branch133
  %load_FillHead219 = load i16, ptr %FillHead, align 2
  %219 = sext i16 %load_FillHead219 to i32
  %tmpVar220 = icmp slt i32 %219, 40
  %220 = zext i1 %tmpVar220 to i8
  %221 = icmp ne i8 %220, 0
  br i1 %221, label %condition_body221, label %branch135

condition_body221:                                ; preds = %branch134
  %load_PVsum223 = load i16, ptr %PVsum, align 2
  %222 = sext i16 %load_PVsum223 to i32
  %tmpVar224 = icmp slt i32 %222, 95
  %223 = zext i1 %tmpVar224 to i8
  %224 = icmp ne i8 %223, 0
  br i1 %224, label %364, label %360

branch135:                                        ; preds = %branch134
  %load_FillHead239 = load i16, ptr %FillHead, align 2
  %225 = sext i16 %load_FillHead239 to i32
  %tmpVar240 = icmp slt i32 %225, 48
  %226 = zext i1 %tmpVar240 to i8
  %227 = icmp ne i8 %226, 0
  br i1 %227, label %condition_body241, label %branch136

condition_body241:                                ; preds = %branch135
  %load_PVsum243 = load i16, ptr %PVsum, align 2
  %228 = sext i16 %load_PVsum243 to i32
  %tmpVar244 = icmp slt i32 %228, 65
  %229 = zext i1 %tmpVar244 to i8
  %230 = icmp ne i8 %229, 0
  br i1 %230, label %393, label %389

branch136:                                        ; preds = %branch135
  %load_FillHead259 = load i16, ptr %FillHead, align 2
  %231 = sext i16 %load_FillHead259 to i32
  %tmpVar260 = icmp slt i32 %231, 56
  %232 = zext i1 %tmpVar260 to i8
  %233 = icmp ne i8 %232, 0
  br i1 %233, label %condition_body261, label %else137

condition_body261:                                ; preds = %branch136
  %load_PVsum263 = load i16, ptr %PVsum, align 2
  %234 = sext i16 %load_PVsum263 to i32
  %tmpVar264 = icmp slt i32 %234, 85
  %235 = zext i1 %tmpVar264 to i8
  %236 = icmp ne i8 %235, 0
  br i1 %236, label %422, label %418

else137:                                          ; preds = %branch136
  %load_PVsum280 = load i16, ptr %PVsum, align 2
  %237 = sext i16 %load_PVsum280 to i32
  %tmpVar281 = icmp slt i32 %237, 75
  %238 = zext i1 %tmpVar281 to i8
  %239 = icmp ne i8 %238, 0
  br i1 %239, label %451, label %447

continue138:                                      ; preds = %continue279, %continue262, %continue242, %continue222, %continue202, %continue182, %continue162, %continue142
  %load_FillHead296 = load i16, ptr %FillHead, align 2
  %240 = sext i16 %load_FillHead296 to i32
  %tmpVar297 = mul i32 1, %240
  %tmpVar298 = add i32 %tmpVar297, 0
  %tmpVar299 = getelementptr inbounds [64 x i16], ptr %Buffer, i32 0, i32 %tmpVar298
  %load_CycleCount300 = load i16, ptr %CycleCount, align 2
  store i16 %load_CycleCount300, ptr %tmpVar299, align 2
  br label %continue

condition_body151:                                ; preds = %264
  %load_FillHead154 = load i16, ptr %FillHead, align 2
  %241 = sext i16 %load_FillHead154 to i32
  %tmpVar155 = icmp sgt i32 %241, 5
  %242 = zext i1 %tmpVar155 to i8
  %243 = icmp ne i8 %242, 0
  br i1 %243, label %condition_body156, label %else152

continue142:                                      ; preds = %continue153, %264
  br label %continue138

244:                                              ; preds = %condition_body141
  %load_PVsum145 = load i16, ptr %PVsum, align 2
  %245 = sext i16 %load_PVsum145 to i32
  %tmpVar146 = icmp sgt i32 %245, 90
  %246 = zext i1 %tmpVar146 to i8
  %247 = icmp ne i8 %246, 0
  br label %248

248:                                              ; preds = %244, %condition_body141
  %249 = phi i1 [ %200, %condition_body141 ], [ %247, %244 ]
  %250 = zext i1 %249 to i8
  %251 = icmp ne i8 %250, 0
  br i1 %251, label %256, label %252

252:                                              ; preds = %248
  %load_PipeTemp147 = load i16, ptr %PipeTemp, align 2
  %253 = sext i16 %load_PipeTemp147 to i32
  %tmpVar148 = icmp slt i32 %253, 50
  %254 = zext i1 %tmpVar148 to i8
  %255 = icmp ne i8 %254, 0
  br label %256

256:                                              ; preds = %252, %248
  %257 = phi i1 [ %251, %248 ], [ %255, %252 ]
  %258 = zext i1 %257 to i8
  %259 = icmp ne i8 %258, 0
  br i1 %259, label %264, label %260

260:                                              ; preds = %256
  %load_PipeTemp149 = load i16, ptr %PipeTemp, align 2
  %261 = sext i16 %load_PipeTemp149 to i32
  %tmpVar150 = icmp sgt i32 %261, 65
  %262 = zext i1 %tmpVar150 to i8
  %263 = icmp ne i8 %262, 0
  br label %264

264:                                              ; preds = %260, %256
  %265 = phi i1 [ %259, %256 ], [ %263, %260 ]
  %266 = zext i1 %265 to i8
  %267 = icmp ne i8 %266, 0
  br i1 %267, label %condition_body151, label %continue142

condition_body156:                                ; preds = %condition_body151
  %load_FillHead157 = load i16, ptr %FillHead, align 2
  %268 = sext i16 %load_FillHead157 to i32
  %tmpVar158 = sub i32 %268, 6
  %269 = trunc i32 %tmpVar158 to i16
  store i16 %269, ptr %FillHead, align 2
  br label %continue153

else152:                                          ; preds = %condition_body151
  store i16 0, ptr %FillHead, align 2
  br label %continue153

continue153:                                      ; preds = %else152, %condition_body156
  br label %continue142

condition_body171:                                ; preds = %293
  %load_FillHead174 = load i16, ptr %FillHead, align 2
  %270 = sext i16 %load_FillHead174 to i32
  %tmpVar175 = icmp sgt i32 %270, 5
  %271 = zext i1 %tmpVar175 to i8
  %272 = icmp ne i8 %271, 0
  br i1 %272, label %condition_body176, label %else172

continue162:                                      ; preds = %continue173, %293
  br label %continue138

273:                                              ; preds = %condition_body161
  %load_PVsum165 = load i16, ptr %PVsum, align 2
  %274 = sext i16 %load_PVsum165 to i32
  %tmpVar166 = icmp sgt i32 %274, 110
  %275 = zext i1 %tmpVar166 to i8
  %276 = icmp ne i8 %275, 0
  br label %277

277:                                              ; preds = %273, %condition_body161
  %278 = phi i1 [ %206, %condition_body161 ], [ %276, %273 ]
  %279 = zext i1 %278 to i8
  %280 = icmp ne i8 %279, 0
  br i1 %280, label %285, label %281

281:                                              ; preds = %277
  %load_PipeTemp167 = load i16, ptr %PipeTemp, align 2
  %282 = sext i16 %load_PipeTemp167 to i32
  %tmpVar168 = icmp slt i32 %282, 62
  %283 = zext i1 %tmpVar168 to i8
  %284 = icmp ne i8 %283, 0
  br label %285

285:                                              ; preds = %281, %277
  %286 = phi i1 [ %280, %277 ], [ %284, %281 ]
  %287 = zext i1 %286 to i8
  %288 = icmp ne i8 %287, 0
  br i1 %288, label %293, label %289

289:                                              ; preds = %285
  %load_PipeTemp169 = load i16, ptr %PipeTemp, align 2
  %290 = sext i16 %load_PipeTemp169 to i32
  %tmpVar170 = icmp sgt i32 %290, 77
  %291 = zext i1 %tmpVar170 to i8
  %292 = icmp ne i8 %291, 0
  br label %293

293:                                              ; preds = %289, %285
  %294 = phi i1 [ %288, %285 ], [ %292, %289 ]
  %295 = zext i1 %294 to i8
  %296 = icmp ne i8 %295, 0
  br i1 %296, label %condition_body171, label %continue162

condition_body176:                                ; preds = %condition_body171
  %load_FillHead177 = load i16, ptr %FillHead, align 2
  %297 = sext i16 %load_FillHead177 to i32
  %tmpVar178 = sub i32 %297, 6
  %298 = trunc i32 %tmpVar178 to i16
  store i16 %298, ptr %FillHead, align 2
  br label %continue173

else172:                                          ; preds = %condition_body171
  store i16 0, ptr %FillHead, align 2
  br label %continue173

continue173:                                      ; preds = %else172, %condition_body176
  br label %continue162

condition_body191:                                ; preds = %322
  %load_FillHead194 = load i16, ptr %FillHead, align 2
  %299 = sext i16 %load_FillHead194 to i32
  %tmpVar195 = icmp sgt i32 %299, 5
  %300 = zext i1 %tmpVar195 to i8
  %301 = icmp ne i8 %300, 0
  br i1 %301, label %condition_body196, label %else192

continue182:                                      ; preds = %continue193, %322
  br label %continue138

302:                                              ; preds = %condition_body181
  %load_PVsum185 = load i16, ptr %PVsum, align 2
  %303 = sext i16 %load_PVsum185 to i32
  %tmpVar186 = icmp sgt i32 %303, 100
  %304 = zext i1 %tmpVar186 to i8
  %305 = icmp ne i8 %304, 0
  br label %306

306:                                              ; preds = %302, %condition_body181
  %307 = phi i1 [ %212, %condition_body181 ], [ %305, %302 ]
  %308 = zext i1 %307 to i8
  %309 = icmp ne i8 %308, 0
  br i1 %309, label %314, label %310

310:                                              ; preds = %306
  %load_PipeTemp187 = load i16, ptr %PipeTemp, align 2
  %311 = sext i16 %load_PipeTemp187 to i32
  %tmpVar188 = icmp slt i32 %311, 72
  %312 = zext i1 %tmpVar188 to i8
  %313 = icmp ne i8 %312, 0
  br label %314

314:                                              ; preds = %310, %306
  %315 = phi i1 [ %309, %306 ], [ %313, %310 ]
  %316 = zext i1 %315 to i8
  %317 = icmp ne i8 %316, 0
  br i1 %317, label %322, label %318

318:                                              ; preds = %314
  %load_PipeTemp189 = load i16, ptr %PipeTemp, align 2
  %319 = sext i16 %load_PipeTemp189 to i32
  %tmpVar190 = icmp sgt i32 %319, 87
  %320 = zext i1 %tmpVar190 to i8
  %321 = icmp ne i8 %320, 0
  br label %322

322:                                              ; preds = %318, %314
  %323 = phi i1 [ %317, %314 ], [ %321, %318 ]
  %324 = zext i1 %323 to i8
  %325 = icmp ne i8 %324, 0
  br i1 %325, label %condition_body191, label %continue182

condition_body196:                                ; preds = %condition_body191
  %load_FillHead197 = load i16, ptr %FillHead, align 2
  %326 = sext i16 %load_FillHead197 to i32
  %tmpVar198 = sub i32 %326, 6
  %327 = trunc i32 %tmpVar198 to i16
  store i16 %327, ptr %FillHead, align 2
  br label %continue193

else192:                                          ; preds = %condition_body191
  store i16 0, ptr %FillHead, align 2
  br label %continue193

continue193:                                      ; preds = %else192, %condition_body196
  br label %continue182

condition_body211:                                ; preds = %351
  %load_FillHead214 = load i16, ptr %FillHead, align 2
  %328 = sext i16 %load_FillHead214 to i32
  %tmpVar215 = icmp sgt i32 %328, 5
  %329 = zext i1 %tmpVar215 to i8
  %330 = icmp ne i8 %329, 0
  br i1 %330, label %condition_body216, label %else212

continue202:                                      ; preds = %continue213, %351
  br label %continue138

331:                                              ; preds = %condition_body201
  %load_PVsum205 = load i16, ptr %PVsum, align 2
  %332 = sext i16 %load_PVsum205 to i32
  %tmpVar206 = icmp sgt i32 %332, 85
  %333 = zext i1 %tmpVar206 to i8
  %334 = icmp ne i8 %333, 0
  br label %335

335:                                              ; preds = %331, %condition_body201
  %336 = phi i1 [ %218, %condition_body201 ], [ %334, %331 ]
  %337 = zext i1 %336 to i8
  %338 = icmp ne i8 %337, 0
  br i1 %338, label %343, label %339

339:                                              ; preds = %335
  %load_PipeTemp207 = load i16, ptr %PipeTemp, align 2
  %340 = sext i16 %load_PipeTemp207 to i32
  %tmpVar208 = icmp slt i32 %340, 65
  %341 = zext i1 %tmpVar208 to i8
  %342 = icmp ne i8 %341, 0
  br label %343

343:                                              ; preds = %339, %335
  %344 = phi i1 [ %338, %335 ], [ %342, %339 ]
  %345 = zext i1 %344 to i8
  %346 = icmp ne i8 %345, 0
  br i1 %346, label %351, label %347

347:                                              ; preds = %343
  %load_PipeTemp209 = load i16, ptr %PipeTemp, align 2
  %348 = sext i16 %load_PipeTemp209 to i32
  %tmpVar210 = icmp sgt i32 %348, 80
  %349 = zext i1 %tmpVar210 to i8
  %350 = icmp ne i8 %349, 0
  br label %351

351:                                              ; preds = %347, %343
  %352 = phi i1 [ %346, %343 ], [ %350, %347 ]
  %353 = zext i1 %352 to i8
  %354 = icmp ne i8 %353, 0
  br i1 %354, label %condition_body211, label %continue202

condition_body216:                                ; preds = %condition_body211
  %load_FillHead217 = load i16, ptr %FillHead, align 2
  %355 = sext i16 %load_FillHead217 to i32
  %tmpVar218 = sub i32 %355, 6
  %356 = trunc i32 %tmpVar218 to i16
  store i16 %356, ptr %FillHead, align 2
  br label %continue213

else212:                                          ; preds = %condition_body211
  store i16 0, ptr %FillHead, align 2
  br label %continue213

continue213:                                      ; preds = %else212, %condition_body216
  br label %continue202

condition_body231:                                ; preds = %380
  %load_FillHead234 = load i16, ptr %FillHead, align 2
  %357 = sext i16 %load_FillHead234 to i32
  %tmpVar235 = icmp sgt i32 %357, 5
  %358 = zext i1 %tmpVar235 to i8
  %359 = icmp ne i8 %358, 0
  br i1 %359, label %condition_body236, label %else232

continue222:                                      ; preds = %continue233, %380
  br label %continue138

360:                                              ; preds = %condition_body221
  %load_PVsum225 = load i16, ptr %PVsum, align 2
  %361 = sext i16 %load_PVsum225 to i32
  %tmpVar226 = icmp sgt i32 %361, 125
  %362 = zext i1 %tmpVar226 to i8
  %363 = icmp ne i8 %362, 0
  br label %364

364:                                              ; preds = %360, %condition_body221
  %365 = phi i1 [ %224, %condition_body221 ], [ %363, %360 ]
  %366 = zext i1 %365 to i8
  %367 = icmp ne i8 %366, 0
  br i1 %367, label %372, label %368

368:                                              ; preds = %364
  %load_PipeTemp227 = load i16, ptr %PipeTemp, align 2
  %369 = sext i16 %load_PipeTemp227 to i32
  %tmpVar228 = icmp slt i32 %369, 55
  %370 = zext i1 %tmpVar228 to i8
  %371 = icmp ne i8 %370, 0
  br label %372

372:                                              ; preds = %368, %364
  %373 = phi i1 [ %367, %364 ], [ %371, %368 ]
  %374 = zext i1 %373 to i8
  %375 = icmp ne i8 %374, 0
  br i1 %375, label %380, label %376

376:                                              ; preds = %372
  %load_PipeTemp229 = load i16, ptr %PipeTemp, align 2
  %377 = sext i16 %load_PipeTemp229 to i32
  %tmpVar230 = icmp sgt i32 %377, 70
  %378 = zext i1 %tmpVar230 to i8
  %379 = icmp ne i8 %378, 0
  br label %380

380:                                              ; preds = %376, %372
  %381 = phi i1 [ %375, %372 ], [ %379, %376 ]
  %382 = zext i1 %381 to i8
  %383 = icmp ne i8 %382, 0
  br i1 %383, label %condition_body231, label %continue222

condition_body236:                                ; preds = %condition_body231
  %load_FillHead237 = load i16, ptr %FillHead, align 2
  %384 = sext i16 %load_FillHead237 to i32
  %tmpVar238 = sub i32 %384, 6
  %385 = trunc i32 %tmpVar238 to i16
  store i16 %385, ptr %FillHead, align 2
  br label %continue233

else232:                                          ; preds = %condition_body231
  store i16 0, ptr %FillHead, align 2
  br label %continue233

continue233:                                      ; preds = %else232, %condition_body236
  br label %continue222

condition_body251:                                ; preds = %409
  %load_FillHead254 = load i16, ptr %FillHead, align 2
  %386 = sext i16 %load_FillHead254 to i32
  %tmpVar255 = icmp sgt i32 %386, 5
  %387 = zext i1 %tmpVar255 to i8
  %388 = icmp ne i8 %387, 0
  br i1 %388, label %condition_body256, label %else252

continue242:                                      ; preds = %continue253, %409
  br label %continue138

389:                                              ; preds = %condition_body241
  %load_PVsum245 = load i16, ptr %PVsum, align 2
  %390 = sext i16 %load_PVsum245 to i32
  %tmpVar246 = icmp sgt i32 %390, 95
  %391 = zext i1 %tmpVar246 to i8
  %392 = icmp ne i8 %391, 0
  br label %393

393:                                              ; preds = %389, %condition_body241
  %394 = phi i1 [ %230, %condition_body241 ], [ %392, %389 ]
  %395 = zext i1 %394 to i8
  %396 = icmp ne i8 %395, 0
  br i1 %396, label %401, label %397

397:                                              ; preds = %393
  %load_PipeTemp247 = load i16, ptr %PipeTemp, align 2
  %398 = sext i16 %load_PipeTemp247 to i32
  %tmpVar248 = icmp slt i32 %398, 78
  %399 = zext i1 %tmpVar248 to i8
  %400 = icmp ne i8 %399, 0
  br label %401

401:                                              ; preds = %397, %393
  %402 = phi i1 [ %396, %393 ], [ %400, %397 ]
  %403 = zext i1 %402 to i8
  %404 = icmp ne i8 %403, 0
  br i1 %404, label %409, label %405

405:                                              ; preds = %401
  %load_PipeTemp249 = load i16, ptr %PipeTemp, align 2
  %406 = sext i16 %load_PipeTemp249 to i32
  %tmpVar250 = icmp sgt i32 %406, 93
  %407 = zext i1 %tmpVar250 to i8
  %408 = icmp ne i8 %407, 0
  br label %409

409:                                              ; preds = %405, %401
  %410 = phi i1 [ %404, %401 ], [ %408, %405 ]
  %411 = zext i1 %410 to i8
  %412 = icmp ne i8 %411, 0
  br i1 %412, label %condition_body251, label %continue242

condition_body256:                                ; preds = %condition_body251
  %load_FillHead257 = load i16, ptr %FillHead, align 2
  %413 = sext i16 %load_FillHead257 to i32
  %tmpVar258 = sub i32 %413, 6
  %414 = trunc i32 %tmpVar258 to i16
  store i16 %414, ptr %FillHead, align 2
  br label %continue253

else252:                                          ; preds = %condition_body251
  store i16 0, ptr %FillHead, align 2
  br label %continue253

continue253:                                      ; preds = %else252, %condition_body256
  br label %continue242

condition_body271:                                ; preds = %438
  %load_FillHead274 = load i16, ptr %FillHead, align 2
  %415 = sext i16 %load_FillHead274 to i32
  %tmpVar275 = icmp sgt i32 %415, 5
  %416 = zext i1 %tmpVar275 to i8
  %417 = icmp ne i8 %416, 0
  br i1 %417, label %condition_body276, label %else272

continue262:                                      ; preds = %continue273, %438
  br label %continue138

418:                                              ; preds = %condition_body261
  %load_PVsum265 = load i16, ptr %PVsum, align 2
  %419 = sext i16 %load_PVsum265 to i32
  %tmpVar266 = icmp sgt i32 %419, 115
  %420 = zext i1 %tmpVar266 to i8
  %421 = icmp ne i8 %420, 0
  br label %422

422:                                              ; preds = %418, %condition_body261
  %423 = phi i1 [ %236, %condition_body261 ], [ %421, %418 ]
  %424 = zext i1 %423 to i8
  %425 = icmp ne i8 %424, 0
  br i1 %425, label %430, label %426

426:                                              ; preds = %422
  %load_PipeTemp267 = load i16, ptr %PipeTemp, align 2
  %427 = sext i16 %load_PipeTemp267 to i32
  %tmpVar268 = icmp slt i32 %427, 52
  %428 = zext i1 %tmpVar268 to i8
  %429 = icmp ne i8 %428, 0
  br label %430

430:                                              ; preds = %426, %422
  %431 = phi i1 [ %425, %422 ], [ %429, %426 ]
  %432 = zext i1 %431 to i8
  %433 = icmp ne i8 %432, 0
  br i1 %433, label %438, label %434

434:                                              ; preds = %430
  %load_PipeTemp269 = load i16, ptr %PipeTemp, align 2
  %435 = sext i16 %load_PipeTemp269 to i32
  %tmpVar270 = icmp sgt i32 %435, 67
  %436 = zext i1 %tmpVar270 to i8
  %437 = icmp ne i8 %436, 0
  br label %438

438:                                              ; preds = %434, %430
  %439 = phi i1 [ %433, %430 ], [ %437, %434 ]
  %440 = zext i1 %439 to i8
  %441 = icmp ne i8 %440, 0
  br i1 %441, label %condition_body271, label %continue262

condition_body276:                                ; preds = %condition_body271
  %load_FillHead277 = load i16, ptr %FillHead, align 2
  %442 = sext i16 %load_FillHead277 to i32
  %tmpVar278 = sub i32 %442, 6
  %443 = trunc i32 %tmpVar278 to i16
  store i16 %443, ptr %FillHead, align 2
  br label %continue273

else272:                                          ; preds = %condition_body271
  store i16 0, ptr %FillHead, align 2
  br label %continue273

continue273:                                      ; preds = %else272, %condition_body276
  br label %continue262

condition_body288:                                ; preds = %467
  %load_FillHead291 = load i16, ptr %FillHead, align 2
  %444 = sext i16 %load_FillHead291 to i32
  %tmpVar292 = icmp sgt i32 %444, 5
  %445 = zext i1 %tmpVar292 to i8
  %446 = icmp ne i8 %445, 0
  br i1 %446, label %condition_body293, label %else289

continue279:                                      ; preds = %continue290, %467
  br label %continue138

447:                                              ; preds = %else137
  %load_PVsum282 = load i16, ptr %PVsum, align 2
  %448 = sext i16 %load_PVsum282 to i32
  %tmpVar283 = icmp sgt i32 %448, 105
  %449 = zext i1 %tmpVar283 to i8
  %450 = icmp ne i8 %449, 0
  br label %451

451:                                              ; preds = %447, %else137
  %452 = phi i1 [ %239, %else137 ], [ %450, %447 ]
  %453 = zext i1 %452 to i8
  %454 = icmp ne i8 %453, 0
  br i1 %454, label %459, label %455

455:                                              ; preds = %451
  %load_PipeTemp284 = load i16, ptr %PipeTemp, align 2
  %456 = sext i16 %load_PipeTemp284 to i32
  %tmpVar285 = icmp slt i32 %456, 63
  %457 = zext i1 %tmpVar285 to i8
  %458 = icmp ne i8 %457, 0
  br label %459

459:                                              ; preds = %455, %451
  %460 = phi i1 [ %454, %451 ], [ %458, %455 ]
  %461 = zext i1 %460 to i8
  %462 = icmp ne i8 %461, 0
  br i1 %462, label %467, label %463

463:                                              ; preds = %459
  %load_PipeTemp286 = load i16, ptr %PipeTemp, align 2
  %464 = sext i16 %load_PipeTemp286 to i32
  %tmpVar287 = icmp sgt i32 %464, 78
  %465 = zext i1 %tmpVar287 to i8
  %466 = icmp ne i8 %465, 0
  br label %467

467:                                              ; preds = %463, %459
  %468 = phi i1 [ %462, %459 ], [ %466, %463 ]
  %469 = zext i1 %468 to i8
  %470 = icmp ne i8 %469, 0
  br i1 %470, label %condition_body288, label %continue279

condition_body293:                                ; preds = %condition_body288
  %load_FillHead294 = load i16, ptr %FillHead, align 2
  %471 = sext i16 %load_FillHead294 to i32
  %tmpVar295 = sub i32 %471, 6
  %472 = trunc i32 %tmpVar295 to i16
  store i16 %472, ptr %FillHead, align 2
  br label %continue290

else289:                                          ; preds = %condition_body288
  store i16 0, ptr %FillHead, align 2
  br label %continue290

continue290:                                      ; preds = %else289, %condition_body293
  br label %continue279
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

define void @__unit_program_st__ctor() {
entry:
  call void @__vtable_PipelineCtrl__ctor(ptr @__vtable_PipelineCtrl_instance)
  call void @PLC_PRG__ctor(ptr @PLC_PRG_instance)
  ret void
}
