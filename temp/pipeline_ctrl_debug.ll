; ModuleID = '/var/folders/c5/lhctbtjn68s2kmm80z67rllc0000gn/T/.tmpRY2kc9/icsquartz/benchmarks/pipeline_controller/src/program.st.ll'
source_filename = "/Users/hamza/Documents/NYUAD/2026_Spring/DirectedStudies/StateFuzzer/rusty/icsquartz/benchmarks/pipeline_controller/src/program.st"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-darwin25.3.0"

%__vtable_PipelineCtrl = type { ptr }
%PLC_PRG = type { i16, i16, i16, i16, i16, i16, i8, %PipelineCtrl }
%PipelineCtrl = type { ptr, i16, i16, i16, i16, i16, i16, i8, i8, i8, i16, i16, i16, i16, i16, i16, i16, i16, i16, i16, [64 x i16], i16, i16 }

@PHASE_IDLE = unnamed_addr constant i8 0, !dbg !0
@PHASE_PRIME = unnamed_addr constant i8 1, !dbg !5
@PHASE_FLOW = unnamed_addr constant i8 2, !dbg !7
@PHASE_FILL = unnamed_addr constant i8 3, !dbg !9
@__vtable_PipelineCtrl_instance = global %__vtable_PipelineCtrl zeroinitializer
@PLC_PRG_instance = global %PLC_PRG zeroinitializer, !dbg !11
@llvm.global_ctors = appending global [1 x { i32, ptr, ptr }] [{ i32, ptr, ptr } { i32 65535, ptr @__unit_program_st__ctor, ptr null }]

define void @PipelineCtrl(ptr %0) !dbg !60 {
entry:
    #dbg_declare(ptr %0, !64, !DIExpression(), !65)
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
  %load_CycleCount = load i16, ptr %CycleCount, align 2, !dbg !65
  %1 = sext i16 %load_CycleCount to i32, !dbg !65
  %tmpVar = add i32 %1, 1, !dbg !65
  %2 = trunc i32 %tmpVar to i16, !dbg !65
  store i16 %2, ptr %CycleCount, align 2, !dbg !65
  %load_Phase = load i8, ptr %Phase, align 1, !dbg !65
  switch i8 %load_Phase, label %else [
    i8 0, label %case
    i8 1, label %case8
    i8 2, label %case37
    i8 3, label %case69
  ], !dbg !66

case:                                             ; preds = %entry
  %load_Cmd = load i8, ptr %Cmd, align 1, !dbg !67
  %3 = sext i8 %load_Cmd to i32, !dbg !67
  %tmpVar2 = icmp eq i32 %3, 1, !dbg !67
  %4 = zext i1 %tmpVar2 to i8, !dbg !67
  %5 = icmp ne i8 %4, 0, !dbg !67
  br i1 %5, label %condition_body, label %continue1, !dbg !67

case8:                                            ; preds = %entry
  %load_PrimeCycles = load i16, ptr %PrimeCycles, align 2, !dbg !68
  %6 = sext i16 %load_PrimeCycles to i32, !dbg !68
  %tmpVar9 = add i32 %6, 1, !dbg !68
  %7 = trunc i32 %tmpVar9 to i16, !dbg !68
  store i16 %7, ptr %PrimeCycles, align 2, !dbg !68
  %load_PumpRate = load i16, ptr %PumpRate, align 2, !dbg !69
  %8 = sext i16 %load_PumpRate to i32, !dbg !69
  %load_BackPressure = load i16, ptr %BackPressure, align 2, !dbg !69
  %9 = sext i16 %load_BackPressure to i32, !dbg !69
  %tmpVar10 = add i32 %8, %9, !dbg !69
  %10 = trunc i32 %tmpVar10 to i16, !dbg !69
  store i16 %10, ptr %PVsum, align 2, !dbg !69
  %load_PrimeCycles12 = load i16, ptr %PrimeCycles, align 2, !dbg !70
  %11 = sext i16 %load_PrimeCycles12 to i32, !dbg !70
  %tmpVar13 = srem i32 %11, 3, !dbg !70
  %tmpVar14 = icmp eq i32 %tmpVar13, 0, !dbg !70
  %12 = zext i1 %tmpVar14 to i8, !dbg !70
  %13 = icmp ne i8 %12, 0, !dbg !70
  br i1 %13, label %condition_body15, label %continue11, !dbg !70

case37:                                           ; preds = %entry
  %load_PipeTemp = load i16, ptr %PipeTemp, align 2, !dbg !71
  %14 = sext i16 %load_PipeTemp to i32, !dbg !71
  %load_CoolantRate = load i16, ptr %CoolantRate, align 2, !dbg !71
  %15 = sext i16 %load_CoolantRate to i32, !dbg !71
  %tmpVar38 = add i32 %14, %15, !dbg !71
  %16 = trunc i32 %tmpVar38 to i16, !dbg !71
  store i16 %16, ptr %FluxSum, align 2, !dbg !71
  %load_FluxSum = load i16, ptr %FluxSum, align 2, !dbg !72
  %17 = sext i16 %load_FluxSum to i32, !dbg !72
  %tmpVar41 = icmp sge i32 %17, 80, !dbg !72
  %18 = zext i1 %tmpVar41 to i8, !dbg !72
  %19 = icmp ne i8 %18, 0, !dbg !72
  br i1 %19, label %78, label %82, !dbg !72

case69:                                           ; preds = %entry
  %load_PhaseCounter = load i16, ptr %PhaseCounter, align 2, !dbg !73
  %20 = sext i16 %load_PhaseCounter to i32, !dbg !73
  %tmpVar70 = add i32 %20, 1, !dbg !73
  %21 = trunc i32 %tmpVar70 to i16, !dbg !73
  store i16 %21, ptr %PhaseCounter, align 2, !dbg !73
  %load_PumpRate73 = load i16, ptr %PumpRate, align 2, !dbg !74
  %22 = sext i16 %load_PumpRate73 to i32, !dbg !74
  %tmpVar74 = icmp sge i32 %22, 40, !dbg !74
  %23 = zext i1 %tmpVar74 to i8, !dbg !74
  %24 = icmp ne i8 %23, 0, !dbg !74
  br i1 %24, label %125, label %129, !dbg !74

else:                                             ; preds = %entry
  br label %continue, !dbg !75

continue:                                         ; preds = %continue138, %continue65, %continue33, %continue1, %else
  %load_Phase301 = load i8, ptr %Phase, align 1, !dbg !76
  store i8 %load_Phase301, ptr %Status, align 1, !dbg !76
  ret void, !dbg !77

condition_body:                                   ; preds = %case
  store i16 0, ptr %i, align 2, !dbg !78
  br i1 true, label %predicate_sle, label %predicate_sge, !dbg !78

continue1:                                        ; preds = %continue3, %case
  br label %continue, !dbg !75

predicate_sle:                                    ; preds = %increment, %condition_body
  %25 = load i16, ptr %i, align 2, !dbg !78
  %26 = sext i16 %25 to i32, !dbg !78
  %condition = icmp sle i32 %26, 63, !dbg !78
  br i1 %condition, label %loop, label %continue3, !dbg !78

predicate_sge:                                    ; preds = %increment, %condition_body
  %27 = load i16, ptr %i, align 2, !dbg !78
  %28 = sext i16 %27 to i32, !dbg !78
  %condition4 = icmp sge i32 %28, 63, !dbg !78
  br i1 %condition4, label %loop, label %continue3, !dbg !78

loop:                                             ; preds = %predicate_sge, %predicate_sle
  %load_i = load i16, ptr %i, align 2, !dbg !79
  %29 = sext i16 %load_i to i32, !dbg !79
  %tmpVar5 = mul i32 1, %29, !dbg !79
  %tmpVar6 = add i32 %tmpVar5, 0, !dbg !79
  %tmpVar7 = getelementptr inbounds [64 x i16], ptr %Buffer, i32 0, i32 %tmpVar6, !dbg !79
  store i16 0, ptr %tmpVar7, align 2, !dbg !79
  br label %increment, !dbg !80

increment:                                        ; preds = %loop
  %30 = load i16, ptr %i, align 2, !dbg !80
  %31 = sext i16 %30 to i32, !dbg !80
  %next = add i32 1, %31, !dbg !80
  %32 = trunc i32 %next to i16, !dbg !80
  store i16 %32, ptr %i, align 2, !dbg !80
  br i1 true, label %predicate_sle, label %predicate_sge, !dbg !80

continue3:                                        ; preds = %predicate_sge, %predicate_sle
  store i16 0, ptr %PrimeCycles, align 2, !dbg !81
  store i16 0, ptr %PrimeScore, align 2, !dbg !82
  store i16 0, ptr %FluxScore, align 2, !dbg !83
  store i16 0, ptr %FlowAccum, align 2, !dbg !84
  store i16 0, ptr %PressAccum, align 2, !dbg !85
  store i16 0, ptr %TempAccum, align 2, !dbg !86
  store i16 0, ptr %PhaseCounter, align 2, !dbg !87
  store i16 0, ptr %FillHead, align 2, !dbg !88
  store i16 0, ptr %PVsum, align 2, !dbg !89
  store i8 1, ptr %Phase, align 1, !dbg !90
  br label %continue1, !dbg !91

condition_body15:                                 ; preds = %case8
  %load_PVsum = load i16, ptr %PVsum, align 2, !dbg !92
  %33 = sext i16 %load_PVsum to i32, !dbg !92
  %tmpVar18 = icmp sge i32 %33, 80, !dbg !92
  %34 = zext i1 %tmpVar18 to i8, !dbg !92
  %35 = icmp ne i8 %34, 0, !dbg !92
  br i1 %35, label %44, label %48, !dbg !92

continue11:                                       ; preds = %continue17, %case8
  %load_PrimeScore34 = load i16, ptr %PrimeScore, align 2, !dbg !93
  %36 = sext i16 %load_PrimeScore34 to i32, !dbg !93
  %tmpVar35 = icmp sge i32 %36, 8, !dbg !93
  %37 = zext i1 %tmpVar35 to i8, !dbg !93
  %38 = icmp ne i8 %37, 0, !dbg !93
  br i1 %38, label %condition_body36, label %continue33, !dbg !93

condition_body24:                                 ; preds = %64
  %load_PrimeScore = load i16, ptr %PrimeScore, align 2, !dbg !94
  %39 = sext i16 %load_PrimeScore to i32, !dbg !94
  %tmpVar25 = add i32 %39, 1, !dbg !94
  %40 = trunc i32 %tmpVar25 to i16, !dbg !94
  store i16 %40, ptr %PrimeScore, align 2, !dbg !94
  br label %continue17, !dbg !95

else16:                                           ; preds = %64
  %load_PrimeScore28 = load i16, ptr %PrimeScore, align 2, !dbg !96
  %41 = sext i16 %load_PrimeScore28 to i32, !dbg !96
  %tmpVar29 = icmp sgt i32 %41, 1, !dbg !96
  %42 = zext i1 %tmpVar29 to i8, !dbg !96
  %43 = icmp ne i8 %42, 0, !dbg !96
  br i1 %43, label %condition_body30, label %else26, !dbg !96

continue17:                                       ; preds = %continue27, %condition_body24
  br label %continue11, !dbg !97

44:                                               ; preds = %condition_body15
  %load_PVsum19 = load i16, ptr %PVsum, align 2, !dbg !92
  %45 = sext i16 %load_PVsum19 to i32, !dbg !92
  %tmpVar20 = icmp sle i32 %45, 160, !dbg !92
  %46 = zext i1 %tmpVar20 to i8, !dbg !92
  %47 = icmp ne i8 %46, 0, !dbg !92
  br label %48, !dbg !92

48:                                               ; preds = %44, %condition_body15
  %49 = phi i1 [ %35, %condition_body15 ], [ %47, %44 ], !dbg !92
  %50 = zext i1 %49 to i8, !dbg !92
  %51 = icmp ne i8 %50, 0, !dbg !92
  br i1 %51, label %52, label %56, !dbg !92

52:                                               ; preds = %48
  %load_ValvePos = load i16, ptr %ValvePos, align 2, !dbg !92
  %53 = sext i16 %load_ValvePos to i32, !dbg !92
  %tmpVar21 = icmp sge i32 %53, 15, !dbg !92
  %54 = zext i1 %tmpVar21 to i8, !dbg !92
  %55 = icmp ne i8 %54, 0, !dbg !92
  br label %56, !dbg !92

56:                                               ; preds = %52, %48
  %57 = phi i1 [ %51, %48 ], [ %55, %52 ], !dbg !92
  %58 = zext i1 %57 to i8, !dbg !92
  %59 = icmp ne i8 %58, 0, !dbg !92
  br i1 %59, label %60, label %64, !dbg !92

60:                                               ; preds = %56
  %load_ValvePos22 = load i16, ptr %ValvePos, align 2, !dbg !92
  %61 = sext i16 %load_ValvePos22 to i32, !dbg !92
  %tmpVar23 = icmp sle i32 %61, 60, !dbg !92
  %62 = zext i1 %tmpVar23 to i8, !dbg !92
  %63 = icmp ne i8 %62, 0, !dbg !92
  br label %64, !dbg !92

64:                                               ; preds = %60, %56
  %65 = phi i1 [ %59, %56 ], [ %63, %60 ], !dbg !92
  %66 = zext i1 %65 to i8, !dbg !92
  %67 = icmp ne i8 %66, 0, !dbg !92
  br i1 %67, label %condition_body24, label %else16, !dbg !92

condition_body30:                                 ; preds = %else16
  %load_PrimeScore31 = load i16, ptr %PrimeScore, align 2, !dbg !98
  %68 = sext i16 %load_PrimeScore31 to i32, !dbg !98
  %tmpVar32 = sub i32 %68, 2, !dbg !98
  %69 = trunc i32 %tmpVar32 to i16, !dbg !98
  store i16 %69, ptr %PrimeScore, align 2, !dbg !98
  br label %continue27, !dbg !99

else26:                                           ; preds = %else16
  store i16 0, ptr %PrimeScore, align 2, !dbg !100
  br label %continue27, !dbg !99

continue27:                                       ; preds = %else26, %condition_body30
  br label %continue17, !dbg !95

condition_body36:                                 ; preds = %continue11
  store i8 2, ptr %Phase, align 1, !dbg !101
  br label %continue33, !dbg !102

continue33:                                       ; preds = %condition_body36, %continue11
  br label %continue, !dbg !75

condition_body47:                                 ; preds = %98
  %load_FluxScore = load i16, ptr %FluxScore, align 2, !dbg !103
  %70 = sext i16 %load_FluxScore to i32, !dbg !103
  %tmpVar48 = add i32 %70, 1, !dbg !103
  %71 = trunc i32 %tmpVar48 to i16, !dbg !103
  store i16 %71, ptr %FluxScore, align 2, !dbg !103
  br label %continue40, !dbg !104

else39:                                           ; preds = %98
  %load_FluxScore51 = load i16, ptr %FluxScore, align 2, !dbg !105
  %72 = sext i16 %load_FluxScore51 to i32, !dbg !105
  %tmpVar52 = icmp sgt i32 %72, 1, !dbg !105
  %73 = zext i1 %tmpVar52 to i8, !dbg !105
  %74 = icmp ne i8 %73, 0, !dbg !105
  br i1 %74, label %condition_body53, label %else49, !dbg !105

continue40:                                       ; preds = %continue50, %condition_body47
  %load_CycleCount57 = load i16, ptr %CycleCount, align 2, !dbg !106
  %75 = sext i16 %load_CycleCount57 to i32, !dbg !106
  %tmpVar58 = srem i32 %75, 11, !dbg !106
  %tmpVar59 = icmp eq i32 %tmpVar58, 0, !dbg !106
  %76 = zext i1 %tmpVar59 to i8, !dbg !106
  %77 = icmp ne i8 %76, 0, !dbg !106
  br i1 %77, label %109, label %113, !dbg !106

78:                                               ; preds = %case37
  %load_FluxSum42 = load i16, ptr %FluxSum, align 2, !dbg !72
  %79 = sext i16 %load_FluxSum42 to i32, !dbg !72
  %tmpVar43 = icmp sle i32 %79, 160, !dbg !72
  %80 = zext i1 %tmpVar43 to i8, !dbg !72
  %81 = icmp ne i8 %80, 0, !dbg !72
  br label %82, !dbg !72

82:                                               ; preds = %78, %case37
  %83 = phi i1 [ %19, %case37 ], [ %81, %78 ], !dbg !72
  %84 = zext i1 %83 to i8, !dbg !72
  %85 = icmp ne i8 %84, 0, !dbg !72
  br i1 %85, label %86, label %90, !dbg !72

86:                                               ; preds = %82
  %load_FeedConc = load i16, ptr %FeedConc, align 2, !dbg !72
  %87 = sext i16 %load_FeedConc to i32, !dbg !72
  %tmpVar44 = icmp sge i32 %87, 20, !dbg !72
  %88 = zext i1 %tmpVar44 to i8, !dbg !72
  %89 = icmp ne i8 %88, 0, !dbg !72
  br label %90, !dbg !72

90:                                               ; preds = %86, %82
  %91 = phi i1 [ %85, %82 ], [ %89, %86 ], !dbg !72
  %92 = zext i1 %91 to i8, !dbg !72
  %93 = icmp ne i8 %92, 0, !dbg !72
  br i1 %93, label %94, label %98, !dbg !72

94:                                               ; preds = %90
  %load_FeedConc45 = load i16, ptr %FeedConc, align 2, !dbg !72
  %95 = sext i16 %load_FeedConc45 to i32, !dbg !72
  %tmpVar46 = icmp sle i32 %95, 70, !dbg !72
  %96 = zext i1 %tmpVar46 to i8, !dbg !72
  %97 = icmp ne i8 %96, 0, !dbg !72
  br label %98, !dbg !72

98:                                               ; preds = %94, %90
  %99 = phi i1 [ %93, %90 ], [ %97, %94 ], !dbg !72
  %100 = zext i1 %99 to i8, !dbg !72
  %101 = icmp ne i8 %100, 0, !dbg !72
  br i1 %101, label %condition_body47, label %else39, !dbg !72

condition_body53:                                 ; preds = %else39
  %load_FluxScore54 = load i16, ptr %FluxScore, align 2, !dbg !107
  %102 = sext i16 %load_FluxScore54 to i32, !dbg !107
  %tmpVar55 = sub i32 %102, 2, !dbg !107
  %103 = trunc i32 %tmpVar55 to i16, !dbg !107
  store i16 %103, ptr %FluxScore, align 2, !dbg !107
  br label %continue50, !dbg !108

else49:                                           ; preds = %else39
  store i16 0, ptr %FluxScore, align 2, !dbg !109
  br label %continue50, !dbg !108

continue50:                                       ; preds = %else49, %condition_body53
  br label %continue40, !dbg !104

condition_body62:                                 ; preds = %113
  %load_FluxScore63 = load i16, ptr %FluxScore, align 2, !dbg !110
  %104 = sext i16 %load_FluxScore63 to i32, !dbg !110
  %tmpVar64 = sdiv i32 %104, 2, !dbg !110
  %105 = trunc i32 %tmpVar64 to i16, !dbg !110
  store i16 %105, ptr %FluxScore, align 2, !dbg !110
  br label %continue56, !dbg !111

continue56:                                       ; preds = %113, %condition_body62
  %load_FluxScore66 = load i16, ptr %FluxScore, align 2, !dbg !112
  %106 = sext i16 %load_FluxScore66 to i32, !dbg !112
  %tmpVar67 = icmp sge i32 %106, 8, !dbg !112
  %107 = zext i1 %tmpVar67 to i8, !dbg !112
  %108 = icmp ne i8 %107, 0, !dbg !112
  br i1 %108, label %condition_body68, label %continue65, !dbg !112

109:                                              ; preds = %continue40
  %load_FluxScore60 = load i16, ptr %FluxScore, align 2, !dbg !106
  %110 = sext i16 %load_FluxScore60 to i32, !dbg !106
  %tmpVar61 = icmp sgt i32 %110, 0, !dbg !106
  %111 = zext i1 %tmpVar61 to i8, !dbg !106
  %112 = icmp ne i8 %111, 0, !dbg !106
  br label %113, !dbg !106

113:                                              ; preds = %109, %continue40
  %114 = phi i1 [ %77, %continue40 ], [ %112, %109 ], !dbg !106
  %115 = zext i1 %114 to i8, !dbg !106
  %116 = icmp ne i8 %115, 0, !dbg !106
  br i1 %116, label %condition_body62, label %continue56, !dbg !106

condition_body68:                                 ; preds = %continue56
  store i8 3, ptr %Phase, align 1, !dbg !113
  br label %continue65, !dbg !114

continue65:                                       ; preds = %condition_body68, %continue56
  br label %continue, !dbg !75

condition_body77:                                 ; preds = %129
  %load_FlowAccum = load i16, ptr %FlowAccum, align 2, !dbg !115
  %117 = sext i16 %load_FlowAccum to i32, !dbg !115
  %tmpVar78 = add i32 %117, 1, !dbg !115
  %118 = trunc i32 %tmpVar78 to i16, !dbg !115
  store i16 %118, ptr %FlowAccum, align 2, !dbg !115
  br label %continue72, !dbg !116

else71:                                           ; preds = %129
  %load_FlowAccum81 = load i16, ptr %FlowAccum, align 2, !dbg !117
  %119 = sext i16 %load_FlowAccum81 to i32, !dbg !117
  %tmpVar82 = icmp sgt i32 %119, 1, !dbg !117
  %120 = zext i1 %tmpVar82 to i8, !dbg !117
  %121 = icmp ne i8 %120, 0, !dbg !117
  br i1 %121, label %condition_body83, label %else79, !dbg !117

continue72:                                       ; preds = %continue80, %condition_body77
  %load_BackPressure88 = load i16, ptr %BackPressure, align 2, !dbg !118
  %122 = sext i16 %load_BackPressure88 to i32, !dbg !118
  %tmpVar89 = icmp sge i32 %122, 30, !dbg !118
  %123 = zext i1 %tmpVar89 to i8, !dbg !118
  %124 = icmp ne i8 %123, 0, !dbg !118
  br i1 %124, label %143, label %147, !dbg !118

125:                                              ; preds = %case69
  %load_PumpRate75 = load i16, ptr %PumpRate, align 2, !dbg !74
  %126 = sext i16 %load_PumpRate75 to i32, !dbg !74
  %tmpVar76 = icmp sle i32 %126, 90, !dbg !74
  %127 = zext i1 %tmpVar76 to i8, !dbg !74
  %128 = icmp ne i8 %127, 0, !dbg !74
  br label %129, !dbg !74

129:                                              ; preds = %125, %case69
  %130 = phi i1 [ %24, %case69 ], [ %128, %125 ], !dbg !74
  %131 = zext i1 %130 to i8, !dbg !74
  %132 = icmp ne i8 %131, 0, !dbg !74
  br i1 %132, label %condition_body77, label %else71, !dbg !74

condition_body83:                                 ; preds = %else71
  %load_FlowAccum84 = load i16, ptr %FlowAccum, align 2, !dbg !119
  %133 = sext i16 %load_FlowAccum84 to i32, !dbg !119
  %tmpVar85 = sub i32 %133, 2, !dbg !119
  %134 = trunc i32 %tmpVar85 to i16, !dbg !119
  store i16 %134, ptr %FlowAccum, align 2, !dbg !119
  br label %continue80, !dbg !120

else79:                                           ; preds = %else71
  store i16 0, ptr %FlowAccum, align 2, !dbg !121
  br label %continue80, !dbg !120

continue80:                                       ; preds = %else79, %condition_body83
  br label %continue72, !dbg !116

condition_body92:                                 ; preds = %147
  %load_PressAccum = load i16, ptr %PressAccum, align 2, !dbg !122
  %135 = sext i16 %load_PressAccum to i32, !dbg !122
  %tmpVar93 = add i32 %135, 1, !dbg !122
  %136 = trunc i32 %tmpVar93 to i16, !dbg !122
  store i16 %136, ptr %PressAccum, align 2, !dbg !122
  br label %continue87, !dbg !123

else86:                                           ; preds = %147
  %load_PressAccum95 = load i16, ptr %PressAccum, align 2, !dbg !124
  %137 = sext i16 %load_PressAccum95 to i32, !dbg !124
  %tmpVar96 = icmp sgt i32 %137, 0, !dbg !124
  %138 = zext i1 %tmpVar96 to i8, !dbg !124
  %139 = icmp ne i8 %138, 0, !dbg !124
  br i1 %139, label %condition_body97, label %continue94, !dbg !124

continue87:                                       ; preds = %continue94, %condition_body92
  %load_PipeTemp102 = load i16, ptr %PipeTemp, align 2, !dbg !125
  %140 = sext i16 %load_PipeTemp102 to i32, !dbg !125
  %tmpVar103 = icmp sge i32 %140, 50, !dbg !125
  %141 = zext i1 %tmpVar103 to i8, !dbg !125
  %142 = icmp ne i8 %141, 0, !dbg !125
  br i1 %142, label %161, label %165, !dbg !125

143:                                              ; preds = %continue72
  %load_BackPressure90 = load i16, ptr %BackPressure, align 2, !dbg !118
  %144 = sext i16 %load_BackPressure90 to i32, !dbg !118
  %tmpVar91 = icmp sle i32 %144, 80, !dbg !118
  %145 = zext i1 %tmpVar91 to i8, !dbg !118
  %146 = icmp ne i8 %145, 0, !dbg !118
  br label %147, !dbg !118

147:                                              ; preds = %143, %continue72
  %148 = phi i1 [ %124, %continue72 ], [ %146, %143 ], !dbg !118
  %149 = zext i1 %148 to i8, !dbg !118
  %150 = icmp ne i8 %149, 0, !dbg !118
  br i1 %150, label %condition_body92, label %else86, !dbg !118

condition_body97:                                 ; preds = %else86
  %load_PressAccum98 = load i16, ptr %PressAccum, align 2, !dbg !126
  %151 = sext i16 %load_PressAccum98 to i32, !dbg !126
  %tmpVar99 = sub i32 %151, 1, !dbg !126
  %152 = trunc i32 %tmpVar99 to i16, !dbg !126
  store i16 %152, ptr %PressAccum, align 2, !dbg !126
  br label %continue94, !dbg !127

continue94:                                       ; preds = %condition_body97, %else86
  br label %continue87, !dbg !123

condition_body106:                                ; preds = %165
  %load_TempAccum = load i16, ptr %TempAccum, align 2, !dbg !128
  %153 = sext i16 %load_TempAccum to i32, !dbg !128
  %tmpVar107 = add i32 %153, 1, !dbg !128
  %154 = trunc i32 %tmpVar107 to i16, !dbg !128
  store i16 %154, ptr %TempAccum, align 2, !dbg !128
  br label %continue101, !dbg !129

else100:                                          ; preds = %165
  %load_TempAccum110 = load i16, ptr %TempAccum, align 2, !dbg !130
  %155 = sext i16 %load_TempAccum110 to i32, !dbg !130
  %tmpVar111 = icmp sgt i32 %155, 1, !dbg !130
  %156 = zext i1 %tmpVar111 to i8, !dbg !130
  %157 = icmp ne i8 %156, 0, !dbg !130
  br i1 %157, label %condition_body112, label %else108, !dbg !130

continue101:                                      ; preds = %continue109, %condition_body106
  %load_FlowAccum116 = load i16, ptr %FlowAccum, align 2, !dbg !131
  %158 = sext i16 %load_FlowAccum116 to i32, !dbg !131
  %tmpVar117 = icmp sgt i32 %158, 6, !dbg !131
  %159 = zext i1 %tmpVar117 to i8, !dbg !131
  %160 = icmp ne i8 %159, 0, !dbg !131
  br i1 %160, label %180, label %184, !dbg !131

161:                                              ; preds = %continue87
  %load_PipeTemp104 = load i16, ptr %PipeTemp, align 2, !dbg !125
  %162 = sext i16 %load_PipeTemp104 to i32, !dbg !125
  %tmpVar105 = icmp sle i32 %162, 100, !dbg !125
  %163 = zext i1 %tmpVar105 to i8, !dbg !125
  %164 = icmp ne i8 %163, 0, !dbg !125
  br label %165, !dbg !125

165:                                              ; preds = %161, %continue87
  %166 = phi i1 [ %142, %continue87 ], [ %164, %161 ], !dbg !125
  %167 = zext i1 %166 to i8, !dbg !125
  %168 = icmp ne i8 %167, 0, !dbg !125
  br i1 %168, label %condition_body106, label %else100, !dbg !125

condition_body112:                                ; preds = %else100
  %load_TempAccum113 = load i16, ptr %TempAccum, align 2, !dbg !132
  %169 = sext i16 %load_TempAccum113 to i32, !dbg !132
  %tmpVar114 = sub i32 %169, 2, !dbg !132
  %170 = trunc i32 %tmpVar114 to i16, !dbg !132
  store i16 %170, ptr %TempAccum, align 2, !dbg !132
  br label %continue109, !dbg !133

else108:                                          ; preds = %else100
  store i16 0, ptr %TempAccum, align 2, !dbg !134
  br label %continue109, !dbg !133

continue109:                                      ; preds = %else108, %condition_body112
  br label %continue101, !dbg !129

condition_body122:                                ; preds = %192
  %load_PhaseCounter124 = load i16, ptr %PhaseCounter, align 2, !dbg !135
  %171 = sext i16 %load_PhaseCounter124 to i32, !dbg !135
  %tmpVar125 = srem i32 %171, 4, !dbg !135
  %tmpVar126 = icmp eq i32 %tmpVar125, 0, !dbg !135
  %172 = zext i1 %tmpVar126 to i8, !dbg !135
  %173 = icmp ne i8 %172, 0, !dbg !135
  br i1 %173, label %condition_body127, label %continue123, !dbg !135

continue115:                                      ; preds = %continue123, %192
  %load_PumpRate129 = load i16, ptr %PumpRate, align 2, !dbg !136
  %174 = sext i16 %load_PumpRate129 to i32, !dbg !136
  %load_ValvePos130 = load i16, ptr %ValvePos, align 2, !dbg !136
  %175 = sext i16 %load_ValvePos130 to i32, !dbg !136
  %tmpVar131 = add i32 %174, %175, !dbg !136
  %176 = trunc i32 %tmpVar131 to i16, !dbg !136
  store i16 %176, ptr %PVsum, align 2, !dbg !136
  %load_FillHead139 = load i16, ptr %FillHead, align 2, !dbg !137
  %177 = sext i16 %load_FillHead139 to i32, !dbg !137
  %tmpVar140 = icmp slt i32 %177, 8, !dbg !137
  %178 = zext i1 %tmpVar140 to i8, !dbg !137
  %179 = icmp ne i8 %178, 0, !dbg !137
  br i1 %179, label %condition_body141, label %branch, !dbg !137

180:                                              ; preds = %continue101
  %load_PressAccum118 = load i16, ptr %PressAccum, align 2, !dbg !131
  %181 = sext i16 %load_PressAccum118 to i32, !dbg !131
  %tmpVar119 = icmp sgt i32 %181, 5, !dbg !131
  %182 = zext i1 %tmpVar119 to i8, !dbg !131
  %183 = icmp ne i8 %182, 0, !dbg !131
  br label %184, !dbg !131

184:                                              ; preds = %180, %continue101
  %185 = phi i1 [ %160, %continue101 ], [ %183, %180 ], !dbg !131
  %186 = zext i1 %185 to i8, !dbg !131
  %187 = icmp ne i8 %186, 0, !dbg !131
  br i1 %187, label %188, label %192, !dbg !131

188:                                              ; preds = %184
  %load_TempAccum120 = load i16, ptr %TempAccum, align 2, !dbg !131
  %189 = sext i16 %load_TempAccum120 to i32, !dbg !131
  %tmpVar121 = icmp sgt i32 %189, 6, !dbg !131
  %190 = zext i1 %tmpVar121 to i8, !dbg !131
  %191 = icmp ne i8 %190, 0, !dbg !131
  br label %192, !dbg !131

192:                                              ; preds = %188, %184
  %193 = phi i1 [ %187, %184 ], [ %191, %188 ], !dbg !131
  %194 = zext i1 %193 to i8, !dbg !131
  %195 = icmp ne i8 %194, 0, !dbg !131
  br i1 %195, label %condition_body122, label %continue115, !dbg !131

condition_body127:                                ; preds = %condition_body122
  %load_FillHead = load i16, ptr %FillHead, align 2, !dbg !138
  %196 = sext i16 %load_FillHead to i32, !dbg !138
  %tmpVar128 = add i32 %196, 1, !dbg !138
  %197 = trunc i32 %tmpVar128 to i16, !dbg !138
  store i16 %197, ptr %FillHead, align 2, !dbg !138
  br label %continue123, !dbg !139

continue123:                                      ; preds = %condition_body127, %condition_body122
  br label %continue115, !dbg !140

condition_body141:                                ; preds = %continue115
  %load_PVsum143 = load i16, ptr %PVsum, align 2, !dbg !141
  %198 = sext i16 %load_PVsum143 to i32, !dbg !141
  %tmpVar144 = icmp slt i32 %198, 60, !dbg !141
  %199 = zext i1 %tmpVar144 to i8, !dbg !141
  %200 = icmp ne i8 %199, 0, !dbg !141
  br i1 %200, label %248, label %244, !dbg !141

branch:                                           ; preds = %continue115
  %load_FillHead159 = load i16, ptr %FillHead, align 2, !dbg !142
  %201 = sext i16 %load_FillHead159 to i32, !dbg !142
  %tmpVar160 = icmp slt i32 %201, 16, !dbg !142
  %202 = zext i1 %tmpVar160 to i8, !dbg !142
  %203 = icmp ne i8 %202, 0, !dbg !142
  br i1 %203, label %condition_body161, label %branch132, !dbg !142

condition_body161:                                ; preds = %branch
  %load_PVsum163 = load i16, ptr %PVsum, align 2, !dbg !143
  %204 = sext i16 %load_PVsum163 to i32, !dbg !143
  %tmpVar164 = icmp slt i32 %204, 80, !dbg !143
  %205 = zext i1 %tmpVar164 to i8, !dbg !143
  %206 = icmp ne i8 %205, 0, !dbg !143
  br i1 %206, label %277, label %273, !dbg !143

branch132:                                        ; preds = %branch
  %load_FillHead179 = load i16, ptr %FillHead, align 2, !dbg !144
  %207 = sext i16 %load_FillHead179 to i32, !dbg !144
  %tmpVar180 = icmp slt i32 %207, 24, !dbg !144
  %208 = zext i1 %tmpVar180 to i8, !dbg !144
  %209 = icmp ne i8 %208, 0, !dbg !144
  br i1 %209, label %condition_body181, label %branch133, !dbg !144

condition_body181:                                ; preds = %branch132
  %load_PVsum183 = load i16, ptr %PVsum, align 2, !dbg !145
  %210 = sext i16 %load_PVsum183 to i32, !dbg !145
  %tmpVar184 = icmp slt i32 %210, 70, !dbg !145
  %211 = zext i1 %tmpVar184 to i8, !dbg !145
  %212 = icmp ne i8 %211, 0, !dbg !145
  br i1 %212, label %306, label %302, !dbg !145

branch133:                                        ; preds = %branch132
  %load_FillHead199 = load i16, ptr %FillHead, align 2, !dbg !146
  %213 = sext i16 %load_FillHead199 to i32, !dbg !146
  %tmpVar200 = icmp slt i32 %213, 32, !dbg !146
  %214 = zext i1 %tmpVar200 to i8, !dbg !146
  %215 = icmp ne i8 %214, 0, !dbg !146
  br i1 %215, label %condition_body201, label %branch134, !dbg !146

condition_body201:                                ; preds = %branch133
  %load_PVsum203 = load i16, ptr %PVsum, align 2, !dbg !147
  %216 = sext i16 %load_PVsum203 to i32, !dbg !147
  %tmpVar204 = icmp slt i32 %216, 55, !dbg !147
  %217 = zext i1 %tmpVar204 to i8, !dbg !147
  %218 = icmp ne i8 %217, 0, !dbg !147
  br i1 %218, label %335, label %331, !dbg !147

branch134:                                        ; preds = %branch133
  %load_FillHead219 = load i16, ptr %FillHead, align 2, !dbg !148
  %219 = sext i16 %load_FillHead219 to i32, !dbg !148
  %tmpVar220 = icmp slt i32 %219, 40, !dbg !148
  %220 = zext i1 %tmpVar220 to i8, !dbg !148
  %221 = icmp ne i8 %220, 0, !dbg !148
  br i1 %221, label %condition_body221, label %branch135, !dbg !148

condition_body221:                                ; preds = %branch134
  %load_PVsum223 = load i16, ptr %PVsum, align 2, !dbg !149
  %222 = sext i16 %load_PVsum223 to i32, !dbg !149
  %tmpVar224 = icmp slt i32 %222, 95, !dbg !149
  %223 = zext i1 %tmpVar224 to i8, !dbg !149
  %224 = icmp ne i8 %223, 0, !dbg !149
  br i1 %224, label %364, label %360, !dbg !149

branch135:                                        ; preds = %branch134
  %load_FillHead239 = load i16, ptr %FillHead, align 2, !dbg !150
  %225 = sext i16 %load_FillHead239 to i32, !dbg !150
  %tmpVar240 = icmp slt i32 %225, 48, !dbg !150
  %226 = zext i1 %tmpVar240 to i8, !dbg !150
  %227 = icmp ne i8 %226, 0, !dbg !150
  br i1 %227, label %condition_body241, label %branch136, !dbg !150

condition_body241:                                ; preds = %branch135
  %load_PVsum243 = load i16, ptr %PVsum, align 2, !dbg !151
  %228 = sext i16 %load_PVsum243 to i32, !dbg !151
  %tmpVar244 = icmp slt i32 %228, 65, !dbg !151
  %229 = zext i1 %tmpVar244 to i8, !dbg !151
  %230 = icmp ne i8 %229, 0, !dbg !151
  br i1 %230, label %393, label %389, !dbg !151

branch136:                                        ; preds = %branch135
  %load_FillHead259 = load i16, ptr %FillHead, align 2, !dbg !152
  %231 = sext i16 %load_FillHead259 to i32, !dbg !152
  %tmpVar260 = icmp slt i32 %231, 56, !dbg !152
  %232 = zext i1 %tmpVar260 to i8, !dbg !152
  %233 = icmp ne i8 %232, 0, !dbg !152
  br i1 %233, label %condition_body261, label %else137, !dbg !152

condition_body261:                                ; preds = %branch136
  %load_PVsum263 = load i16, ptr %PVsum, align 2, !dbg !153
  %234 = sext i16 %load_PVsum263 to i32, !dbg !153
  %tmpVar264 = icmp slt i32 %234, 85, !dbg !153
  %235 = zext i1 %tmpVar264 to i8, !dbg !153
  %236 = icmp ne i8 %235, 0, !dbg !153
  br i1 %236, label %422, label %418, !dbg !153

else137:                                          ; preds = %branch136
  %load_PVsum280 = load i16, ptr %PVsum, align 2, !dbg !154
  %237 = sext i16 %load_PVsum280 to i32, !dbg !154
  %tmpVar281 = icmp slt i32 %237, 75, !dbg !154
  %238 = zext i1 %tmpVar281 to i8, !dbg !154
  %239 = icmp ne i8 %238, 0, !dbg !154
  br i1 %239, label %451, label %447, !dbg !154

continue138:                                      ; preds = %continue279, %continue262, %continue242, %continue222, %continue202, %continue182, %continue162, %continue142
  %load_FillHead296 = load i16, ptr %FillHead, align 2, !dbg !155
  %240 = sext i16 %load_FillHead296 to i32, !dbg !155
  %tmpVar297 = mul i32 1, %240, !dbg !155
  %tmpVar298 = add i32 %tmpVar297, 0, !dbg !155
  %tmpVar299 = getelementptr inbounds [64 x i16], ptr %Buffer, i32 0, i32 %tmpVar298, !dbg !155
  %load_CycleCount300 = load i16, ptr %CycleCount, align 2, !dbg !155
  store i16 %load_CycleCount300, ptr %tmpVar299, align 2, !dbg !155
  br label %continue, !dbg !75

condition_body151:                                ; preds = %264
  %load_FillHead154 = load i16, ptr %FillHead, align 2, !dbg !156
  %241 = sext i16 %load_FillHead154 to i32, !dbg !156
  %tmpVar155 = icmp sgt i32 %241, 5, !dbg !156
  %242 = zext i1 %tmpVar155 to i8, !dbg !156
  %243 = icmp ne i8 %242, 0, !dbg !156
  br i1 %243, label %condition_body156, label %else152, !dbg !156

continue142:                                      ; preds = %continue153, %264
  br label %continue138, !dbg !157

244:                                              ; preds = %condition_body141
  %load_PVsum145 = load i16, ptr %PVsum, align 2, !dbg !141
  %245 = sext i16 %load_PVsum145 to i32, !dbg !141
  %tmpVar146 = icmp sgt i32 %245, 90, !dbg !141
  %246 = zext i1 %tmpVar146 to i8, !dbg !141
  %247 = icmp ne i8 %246, 0, !dbg !141
  br label %248, !dbg !141

248:                                              ; preds = %244, %condition_body141
  %249 = phi i1 [ %200, %condition_body141 ], [ %247, %244 ], !dbg !141
  %250 = zext i1 %249 to i8, !dbg !141
  %251 = icmp ne i8 %250, 0, !dbg !141
  br i1 %251, label %256, label %252, !dbg !141

252:                                              ; preds = %248
  %load_PipeTemp147 = load i16, ptr %PipeTemp, align 2, !dbg !141
  %253 = sext i16 %load_PipeTemp147 to i32, !dbg !141
  %tmpVar148 = icmp slt i32 %253, 50, !dbg !141
  %254 = zext i1 %tmpVar148 to i8, !dbg !141
  %255 = icmp ne i8 %254, 0, !dbg !141
  br label %256, !dbg !141

256:                                              ; preds = %252, %248
  %257 = phi i1 [ %251, %248 ], [ %255, %252 ], !dbg !141
  %258 = zext i1 %257 to i8, !dbg !141
  %259 = icmp ne i8 %258, 0, !dbg !141
  br i1 %259, label %264, label %260, !dbg !141

260:                                              ; preds = %256
  %load_PipeTemp149 = load i16, ptr %PipeTemp, align 2, !dbg !141
  %261 = sext i16 %load_PipeTemp149 to i32, !dbg !141
  %tmpVar150 = icmp sgt i32 %261, 65, !dbg !141
  %262 = zext i1 %tmpVar150 to i8, !dbg !141
  %263 = icmp ne i8 %262, 0, !dbg !141
  br label %264, !dbg !141

264:                                              ; preds = %260, %256
  %265 = phi i1 [ %259, %256 ], [ %263, %260 ], !dbg !141
  %266 = zext i1 %265 to i8, !dbg !141
  %267 = icmp ne i8 %266, 0, !dbg !141
  br i1 %267, label %condition_body151, label %continue142, !dbg !141

condition_body156:                                ; preds = %condition_body151
  %load_FillHead157 = load i16, ptr %FillHead, align 2, !dbg !158
  %268 = sext i16 %load_FillHead157 to i32, !dbg !158
  %tmpVar158 = sub i32 %268, 6, !dbg !158
  %269 = trunc i32 %tmpVar158 to i16, !dbg !158
  store i16 %269, ptr %FillHead, align 2, !dbg !158
  br label %continue153, !dbg !159

else152:                                          ; preds = %condition_body151
  store i16 0, ptr %FillHead, align 2, !dbg !160
  br label %continue153, !dbg !159

continue153:                                      ; preds = %else152, %condition_body156
  br label %continue142, !dbg !161

condition_body171:                                ; preds = %293
  %load_FillHead174 = load i16, ptr %FillHead, align 2, !dbg !162
  %270 = sext i16 %load_FillHead174 to i32, !dbg !162
  %tmpVar175 = icmp sgt i32 %270, 5, !dbg !162
  %271 = zext i1 %tmpVar175 to i8, !dbg !162
  %272 = icmp ne i8 %271, 0, !dbg !162
  br i1 %272, label %condition_body176, label %else172, !dbg !162

continue162:                                      ; preds = %continue173, %293
  br label %continue138, !dbg !157

273:                                              ; preds = %condition_body161
  %load_PVsum165 = load i16, ptr %PVsum, align 2, !dbg !143
  %274 = sext i16 %load_PVsum165 to i32, !dbg !143
  %tmpVar166 = icmp sgt i32 %274, 110, !dbg !143
  %275 = zext i1 %tmpVar166 to i8, !dbg !143
  %276 = icmp ne i8 %275, 0, !dbg !143
  br label %277, !dbg !143

277:                                              ; preds = %273, %condition_body161
  %278 = phi i1 [ %206, %condition_body161 ], [ %276, %273 ], !dbg !143
  %279 = zext i1 %278 to i8, !dbg !143
  %280 = icmp ne i8 %279, 0, !dbg !143
  br i1 %280, label %285, label %281, !dbg !143

281:                                              ; preds = %277
  %load_PipeTemp167 = load i16, ptr %PipeTemp, align 2, !dbg !143
  %282 = sext i16 %load_PipeTemp167 to i32, !dbg !143
  %tmpVar168 = icmp slt i32 %282, 62, !dbg !143
  %283 = zext i1 %tmpVar168 to i8, !dbg !143
  %284 = icmp ne i8 %283, 0, !dbg !143
  br label %285, !dbg !143

285:                                              ; preds = %281, %277
  %286 = phi i1 [ %280, %277 ], [ %284, %281 ], !dbg !143
  %287 = zext i1 %286 to i8, !dbg !143
  %288 = icmp ne i8 %287, 0, !dbg !143
  br i1 %288, label %293, label %289, !dbg !143

289:                                              ; preds = %285
  %load_PipeTemp169 = load i16, ptr %PipeTemp, align 2, !dbg !143
  %290 = sext i16 %load_PipeTemp169 to i32, !dbg !143
  %tmpVar170 = icmp sgt i32 %290, 77, !dbg !143
  %291 = zext i1 %tmpVar170 to i8, !dbg !143
  %292 = icmp ne i8 %291, 0, !dbg !143
  br label %293, !dbg !143

293:                                              ; preds = %289, %285
  %294 = phi i1 [ %288, %285 ], [ %292, %289 ], !dbg !143
  %295 = zext i1 %294 to i8, !dbg !143
  %296 = icmp ne i8 %295, 0, !dbg !143
  br i1 %296, label %condition_body171, label %continue162, !dbg !143

condition_body176:                                ; preds = %condition_body171
  %load_FillHead177 = load i16, ptr %FillHead, align 2, !dbg !163
  %297 = sext i16 %load_FillHead177 to i32, !dbg !163
  %tmpVar178 = sub i32 %297, 6, !dbg !163
  %298 = trunc i32 %tmpVar178 to i16, !dbg !163
  store i16 %298, ptr %FillHead, align 2, !dbg !163
  br label %continue173, !dbg !164

else172:                                          ; preds = %condition_body171
  store i16 0, ptr %FillHead, align 2, !dbg !165
  br label %continue173, !dbg !164

continue173:                                      ; preds = %else172, %condition_body176
  br label %continue162, !dbg !166

condition_body191:                                ; preds = %322
  %load_FillHead194 = load i16, ptr %FillHead, align 2, !dbg !167
  %299 = sext i16 %load_FillHead194 to i32, !dbg !167
  %tmpVar195 = icmp sgt i32 %299, 5, !dbg !167
  %300 = zext i1 %tmpVar195 to i8, !dbg !167
  %301 = icmp ne i8 %300, 0, !dbg !167
  br i1 %301, label %condition_body196, label %else192, !dbg !167

continue182:                                      ; preds = %continue193, %322
  br label %continue138, !dbg !157

302:                                              ; preds = %condition_body181
  %load_PVsum185 = load i16, ptr %PVsum, align 2, !dbg !145
  %303 = sext i16 %load_PVsum185 to i32, !dbg !145
  %tmpVar186 = icmp sgt i32 %303, 100, !dbg !145
  %304 = zext i1 %tmpVar186 to i8, !dbg !145
  %305 = icmp ne i8 %304, 0, !dbg !145
  br label %306, !dbg !145

306:                                              ; preds = %302, %condition_body181
  %307 = phi i1 [ %212, %condition_body181 ], [ %305, %302 ], !dbg !145
  %308 = zext i1 %307 to i8, !dbg !145
  %309 = icmp ne i8 %308, 0, !dbg !145
  br i1 %309, label %314, label %310, !dbg !145

310:                                              ; preds = %306
  %load_PipeTemp187 = load i16, ptr %PipeTemp, align 2, !dbg !145
  %311 = sext i16 %load_PipeTemp187 to i32, !dbg !145
  %tmpVar188 = icmp slt i32 %311, 72, !dbg !145
  %312 = zext i1 %tmpVar188 to i8, !dbg !145
  %313 = icmp ne i8 %312, 0, !dbg !145
  br label %314, !dbg !145

314:                                              ; preds = %310, %306
  %315 = phi i1 [ %309, %306 ], [ %313, %310 ], !dbg !145
  %316 = zext i1 %315 to i8, !dbg !145
  %317 = icmp ne i8 %316, 0, !dbg !145
  br i1 %317, label %322, label %318, !dbg !145

318:                                              ; preds = %314
  %load_PipeTemp189 = load i16, ptr %PipeTemp, align 2, !dbg !145
  %319 = sext i16 %load_PipeTemp189 to i32, !dbg !145
  %tmpVar190 = icmp sgt i32 %319, 87, !dbg !145
  %320 = zext i1 %tmpVar190 to i8, !dbg !145
  %321 = icmp ne i8 %320, 0, !dbg !145
  br label %322, !dbg !145

322:                                              ; preds = %318, %314
  %323 = phi i1 [ %317, %314 ], [ %321, %318 ], !dbg !145
  %324 = zext i1 %323 to i8, !dbg !145
  %325 = icmp ne i8 %324, 0, !dbg !145
  br i1 %325, label %condition_body191, label %continue182, !dbg !145

condition_body196:                                ; preds = %condition_body191
  %load_FillHead197 = load i16, ptr %FillHead, align 2, !dbg !168
  %326 = sext i16 %load_FillHead197 to i32, !dbg !168
  %tmpVar198 = sub i32 %326, 6, !dbg !168
  %327 = trunc i32 %tmpVar198 to i16, !dbg !168
  store i16 %327, ptr %FillHead, align 2, !dbg !168
  br label %continue193, !dbg !169

else192:                                          ; preds = %condition_body191
  store i16 0, ptr %FillHead, align 2, !dbg !170
  br label %continue193, !dbg !169

continue193:                                      ; preds = %else192, %condition_body196
  br label %continue182, !dbg !171

condition_body211:                                ; preds = %351
  %load_FillHead214 = load i16, ptr %FillHead, align 2, !dbg !172
  %328 = sext i16 %load_FillHead214 to i32, !dbg !172
  %tmpVar215 = icmp sgt i32 %328, 5, !dbg !172
  %329 = zext i1 %tmpVar215 to i8, !dbg !172
  %330 = icmp ne i8 %329, 0, !dbg !172
  br i1 %330, label %condition_body216, label %else212, !dbg !172

continue202:                                      ; preds = %continue213, %351
  br label %continue138, !dbg !157

331:                                              ; preds = %condition_body201
  %load_PVsum205 = load i16, ptr %PVsum, align 2, !dbg !147
  %332 = sext i16 %load_PVsum205 to i32, !dbg !147
  %tmpVar206 = icmp sgt i32 %332, 85, !dbg !147
  %333 = zext i1 %tmpVar206 to i8, !dbg !147
  %334 = icmp ne i8 %333, 0, !dbg !147
  br label %335, !dbg !147

335:                                              ; preds = %331, %condition_body201
  %336 = phi i1 [ %218, %condition_body201 ], [ %334, %331 ], !dbg !147
  %337 = zext i1 %336 to i8, !dbg !147
  %338 = icmp ne i8 %337, 0, !dbg !147
  br i1 %338, label %343, label %339, !dbg !147

339:                                              ; preds = %335
  %load_PipeTemp207 = load i16, ptr %PipeTemp, align 2, !dbg !147
  %340 = sext i16 %load_PipeTemp207 to i32, !dbg !147
  %tmpVar208 = icmp slt i32 %340, 65, !dbg !147
  %341 = zext i1 %tmpVar208 to i8, !dbg !147
  %342 = icmp ne i8 %341, 0, !dbg !147
  br label %343, !dbg !147

343:                                              ; preds = %339, %335
  %344 = phi i1 [ %338, %335 ], [ %342, %339 ], !dbg !147
  %345 = zext i1 %344 to i8, !dbg !147
  %346 = icmp ne i8 %345, 0, !dbg !147
  br i1 %346, label %351, label %347, !dbg !147

347:                                              ; preds = %343
  %load_PipeTemp209 = load i16, ptr %PipeTemp, align 2, !dbg !147
  %348 = sext i16 %load_PipeTemp209 to i32, !dbg !147
  %tmpVar210 = icmp sgt i32 %348, 80, !dbg !147
  %349 = zext i1 %tmpVar210 to i8, !dbg !147
  %350 = icmp ne i8 %349, 0, !dbg !147
  br label %351, !dbg !147

351:                                              ; preds = %347, %343
  %352 = phi i1 [ %346, %343 ], [ %350, %347 ], !dbg !147
  %353 = zext i1 %352 to i8, !dbg !147
  %354 = icmp ne i8 %353, 0, !dbg !147
  br i1 %354, label %condition_body211, label %continue202, !dbg !147

condition_body216:                                ; preds = %condition_body211
  %load_FillHead217 = load i16, ptr %FillHead, align 2, !dbg !173
  %355 = sext i16 %load_FillHead217 to i32, !dbg !173
  %tmpVar218 = sub i32 %355, 6, !dbg !173
  %356 = trunc i32 %tmpVar218 to i16, !dbg !173
  store i16 %356, ptr %FillHead, align 2, !dbg !173
  br label %continue213, !dbg !174

else212:                                          ; preds = %condition_body211
  store i16 0, ptr %FillHead, align 2, !dbg !175
  br label %continue213, !dbg !174

continue213:                                      ; preds = %else212, %condition_body216
  br label %continue202, !dbg !176

condition_body231:                                ; preds = %380
  %load_FillHead234 = load i16, ptr %FillHead, align 2, !dbg !177
  %357 = sext i16 %load_FillHead234 to i32, !dbg !177
  %tmpVar235 = icmp sgt i32 %357, 5, !dbg !177
  %358 = zext i1 %tmpVar235 to i8, !dbg !177
  %359 = icmp ne i8 %358, 0, !dbg !177
  br i1 %359, label %condition_body236, label %else232, !dbg !177

continue222:                                      ; preds = %continue233, %380
  br label %continue138, !dbg !157

360:                                              ; preds = %condition_body221
  %load_PVsum225 = load i16, ptr %PVsum, align 2, !dbg !149
  %361 = sext i16 %load_PVsum225 to i32, !dbg !149
  %tmpVar226 = icmp sgt i32 %361, 125, !dbg !149
  %362 = zext i1 %tmpVar226 to i8, !dbg !149
  %363 = icmp ne i8 %362, 0, !dbg !149
  br label %364, !dbg !149

364:                                              ; preds = %360, %condition_body221
  %365 = phi i1 [ %224, %condition_body221 ], [ %363, %360 ], !dbg !149
  %366 = zext i1 %365 to i8, !dbg !149
  %367 = icmp ne i8 %366, 0, !dbg !149
  br i1 %367, label %372, label %368, !dbg !149

368:                                              ; preds = %364
  %load_PipeTemp227 = load i16, ptr %PipeTemp, align 2, !dbg !149
  %369 = sext i16 %load_PipeTemp227 to i32, !dbg !149
  %tmpVar228 = icmp slt i32 %369, 55, !dbg !149
  %370 = zext i1 %tmpVar228 to i8, !dbg !149
  %371 = icmp ne i8 %370, 0, !dbg !149
  br label %372, !dbg !149

372:                                              ; preds = %368, %364
  %373 = phi i1 [ %367, %364 ], [ %371, %368 ], !dbg !149
  %374 = zext i1 %373 to i8, !dbg !149
  %375 = icmp ne i8 %374, 0, !dbg !149
  br i1 %375, label %380, label %376, !dbg !149

376:                                              ; preds = %372
  %load_PipeTemp229 = load i16, ptr %PipeTemp, align 2, !dbg !149
  %377 = sext i16 %load_PipeTemp229 to i32, !dbg !149
  %tmpVar230 = icmp sgt i32 %377, 70, !dbg !149
  %378 = zext i1 %tmpVar230 to i8, !dbg !149
  %379 = icmp ne i8 %378, 0, !dbg !149
  br label %380, !dbg !149

380:                                              ; preds = %376, %372
  %381 = phi i1 [ %375, %372 ], [ %379, %376 ], !dbg !149
  %382 = zext i1 %381 to i8, !dbg !149
  %383 = icmp ne i8 %382, 0, !dbg !149
  br i1 %383, label %condition_body231, label %continue222, !dbg !149

condition_body236:                                ; preds = %condition_body231
  %load_FillHead237 = load i16, ptr %FillHead, align 2, !dbg !178
  %384 = sext i16 %load_FillHead237 to i32, !dbg !178
  %tmpVar238 = sub i32 %384, 6, !dbg !178
  %385 = trunc i32 %tmpVar238 to i16, !dbg !178
  store i16 %385, ptr %FillHead, align 2, !dbg !178
  br label %continue233, !dbg !179

else232:                                          ; preds = %condition_body231
  store i16 0, ptr %FillHead, align 2, !dbg !180
  br label %continue233, !dbg !179

continue233:                                      ; preds = %else232, %condition_body236
  br label %continue222, !dbg !181

condition_body251:                                ; preds = %409
  %load_FillHead254 = load i16, ptr %FillHead, align 2, !dbg !182
  %386 = sext i16 %load_FillHead254 to i32, !dbg !182
  %tmpVar255 = icmp sgt i32 %386, 5, !dbg !182
  %387 = zext i1 %tmpVar255 to i8, !dbg !182
  %388 = icmp ne i8 %387, 0, !dbg !182
  br i1 %388, label %condition_body256, label %else252, !dbg !182

continue242:                                      ; preds = %continue253, %409
  br label %continue138, !dbg !157

389:                                              ; preds = %condition_body241
  %load_PVsum245 = load i16, ptr %PVsum, align 2, !dbg !151
  %390 = sext i16 %load_PVsum245 to i32, !dbg !151
  %tmpVar246 = icmp sgt i32 %390, 95, !dbg !151
  %391 = zext i1 %tmpVar246 to i8, !dbg !151
  %392 = icmp ne i8 %391, 0, !dbg !151
  br label %393, !dbg !151

393:                                              ; preds = %389, %condition_body241
  %394 = phi i1 [ %230, %condition_body241 ], [ %392, %389 ], !dbg !151
  %395 = zext i1 %394 to i8, !dbg !151
  %396 = icmp ne i8 %395, 0, !dbg !151
  br i1 %396, label %401, label %397, !dbg !151

397:                                              ; preds = %393
  %load_PipeTemp247 = load i16, ptr %PipeTemp, align 2, !dbg !151
  %398 = sext i16 %load_PipeTemp247 to i32, !dbg !151
  %tmpVar248 = icmp slt i32 %398, 78, !dbg !151
  %399 = zext i1 %tmpVar248 to i8, !dbg !151
  %400 = icmp ne i8 %399, 0, !dbg !151
  br label %401, !dbg !151

401:                                              ; preds = %397, %393
  %402 = phi i1 [ %396, %393 ], [ %400, %397 ], !dbg !151
  %403 = zext i1 %402 to i8, !dbg !151
  %404 = icmp ne i8 %403, 0, !dbg !151
  br i1 %404, label %409, label %405, !dbg !151

405:                                              ; preds = %401
  %load_PipeTemp249 = load i16, ptr %PipeTemp, align 2, !dbg !151
  %406 = sext i16 %load_PipeTemp249 to i32, !dbg !151
  %tmpVar250 = icmp sgt i32 %406, 93, !dbg !151
  %407 = zext i1 %tmpVar250 to i8, !dbg !151
  %408 = icmp ne i8 %407, 0, !dbg !151
  br label %409, !dbg !151

409:                                              ; preds = %405, %401
  %410 = phi i1 [ %404, %401 ], [ %408, %405 ], !dbg !151
  %411 = zext i1 %410 to i8, !dbg !151
  %412 = icmp ne i8 %411, 0, !dbg !151
  br i1 %412, label %condition_body251, label %continue242, !dbg !151

condition_body256:                                ; preds = %condition_body251
  %load_FillHead257 = load i16, ptr %FillHead, align 2, !dbg !183
  %413 = sext i16 %load_FillHead257 to i32, !dbg !183
  %tmpVar258 = sub i32 %413, 6, !dbg !183
  %414 = trunc i32 %tmpVar258 to i16, !dbg !183
  store i16 %414, ptr %FillHead, align 2, !dbg !183
  br label %continue253, !dbg !184

else252:                                          ; preds = %condition_body251
  store i16 0, ptr %FillHead, align 2, !dbg !185
  br label %continue253, !dbg !184

continue253:                                      ; preds = %else252, %condition_body256
  br label %continue242, !dbg !186

condition_body271:                                ; preds = %438
  %load_FillHead274 = load i16, ptr %FillHead, align 2, !dbg !187
  %415 = sext i16 %load_FillHead274 to i32, !dbg !187
  %tmpVar275 = icmp sgt i32 %415, 5, !dbg !187
  %416 = zext i1 %tmpVar275 to i8, !dbg !187
  %417 = icmp ne i8 %416, 0, !dbg !187
  br i1 %417, label %condition_body276, label %else272, !dbg !187

continue262:                                      ; preds = %continue273, %438
  br label %continue138, !dbg !157

418:                                              ; preds = %condition_body261
  %load_PVsum265 = load i16, ptr %PVsum, align 2, !dbg !153
  %419 = sext i16 %load_PVsum265 to i32, !dbg !153
  %tmpVar266 = icmp sgt i32 %419, 115, !dbg !153
  %420 = zext i1 %tmpVar266 to i8, !dbg !153
  %421 = icmp ne i8 %420, 0, !dbg !153
  br label %422, !dbg !153

422:                                              ; preds = %418, %condition_body261
  %423 = phi i1 [ %236, %condition_body261 ], [ %421, %418 ], !dbg !153
  %424 = zext i1 %423 to i8, !dbg !153
  %425 = icmp ne i8 %424, 0, !dbg !153
  br i1 %425, label %430, label %426, !dbg !153

426:                                              ; preds = %422
  %load_PipeTemp267 = load i16, ptr %PipeTemp, align 2, !dbg !153
  %427 = sext i16 %load_PipeTemp267 to i32, !dbg !153
  %tmpVar268 = icmp slt i32 %427, 52, !dbg !153
  %428 = zext i1 %tmpVar268 to i8, !dbg !153
  %429 = icmp ne i8 %428, 0, !dbg !153
  br label %430, !dbg !153

430:                                              ; preds = %426, %422
  %431 = phi i1 [ %425, %422 ], [ %429, %426 ], !dbg !153
  %432 = zext i1 %431 to i8, !dbg !153
  %433 = icmp ne i8 %432, 0, !dbg !153
  br i1 %433, label %438, label %434, !dbg !153

434:                                              ; preds = %430
  %load_PipeTemp269 = load i16, ptr %PipeTemp, align 2, !dbg !153
  %435 = sext i16 %load_PipeTemp269 to i32, !dbg !153
  %tmpVar270 = icmp sgt i32 %435, 67, !dbg !153
  %436 = zext i1 %tmpVar270 to i8, !dbg !153
  %437 = icmp ne i8 %436, 0, !dbg !153
  br label %438, !dbg !153

438:                                              ; preds = %434, %430
  %439 = phi i1 [ %433, %430 ], [ %437, %434 ], !dbg !153
  %440 = zext i1 %439 to i8, !dbg !153
  %441 = icmp ne i8 %440, 0, !dbg !153
  br i1 %441, label %condition_body271, label %continue262, !dbg !153

condition_body276:                                ; preds = %condition_body271
  %load_FillHead277 = load i16, ptr %FillHead, align 2, !dbg !188
  %442 = sext i16 %load_FillHead277 to i32, !dbg !188
  %tmpVar278 = sub i32 %442, 6, !dbg !188
  %443 = trunc i32 %tmpVar278 to i16, !dbg !188
  store i16 %443, ptr %FillHead, align 2, !dbg !188
  br label %continue273, !dbg !189

else272:                                          ; preds = %condition_body271
  store i16 0, ptr %FillHead, align 2, !dbg !190
  br label %continue273, !dbg !189

continue273:                                      ; preds = %else272, %condition_body276
  br label %continue262, !dbg !191

condition_body288:                                ; preds = %467
  %load_FillHead291 = load i16, ptr %FillHead, align 2, !dbg !192
  %444 = sext i16 %load_FillHead291 to i32, !dbg !192
  %tmpVar292 = icmp sgt i32 %444, 5, !dbg !192
  %445 = zext i1 %tmpVar292 to i8, !dbg !192
  %446 = icmp ne i8 %445, 0, !dbg !192
  br i1 %446, label %condition_body293, label %else289, !dbg !192

continue279:                                      ; preds = %continue290, %467
  br label %continue138, !dbg !157

447:                                              ; preds = %else137
  %load_PVsum282 = load i16, ptr %PVsum, align 2, !dbg !154
  %448 = sext i16 %load_PVsum282 to i32, !dbg !154
  %tmpVar283 = icmp sgt i32 %448, 105, !dbg !154
  %449 = zext i1 %tmpVar283 to i8, !dbg !154
  %450 = icmp ne i8 %449, 0, !dbg !154
  br label %451, !dbg !154

451:                                              ; preds = %447, %else137
  %452 = phi i1 [ %239, %else137 ], [ %450, %447 ], !dbg !154
  %453 = zext i1 %452 to i8, !dbg !154
  %454 = icmp ne i8 %453, 0, !dbg !154
  br i1 %454, label %459, label %455, !dbg !154

455:                                              ; preds = %451
  %load_PipeTemp284 = load i16, ptr %PipeTemp, align 2, !dbg !154
  %456 = sext i16 %load_PipeTemp284 to i32, !dbg !154
  %tmpVar285 = icmp slt i32 %456, 63, !dbg !154
  %457 = zext i1 %tmpVar285 to i8, !dbg !154
  %458 = icmp ne i8 %457, 0, !dbg !154
  br label %459, !dbg !154

459:                                              ; preds = %455, %451
  %460 = phi i1 [ %454, %451 ], [ %458, %455 ], !dbg !154
  %461 = zext i1 %460 to i8, !dbg !154
  %462 = icmp ne i8 %461, 0, !dbg !154
  br i1 %462, label %467, label %463, !dbg !154

463:                                              ; preds = %459
  %load_PipeTemp286 = load i16, ptr %PipeTemp, align 2, !dbg !154
  %464 = sext i16 %load_PipeTemp286 to i32, !dbg !154
  %tmpVar287 = icmp sgt i32 %464, 78, !dbg !154
  %465 = zext i1 %tmpVar287 to i8, !dbg !154
  %466 = icmp ne i8 %465, 0, !dbg !154
  br label %467, !dbg !154

467:                                              ; preds = %463, %459
  %468 = phi i1 [ %462, %459 ], [ %466, %463 ], !dbg !154
  %469 = zext i1 %468 to i8, !dbg !154
  %470 = icmp ne i8 %469, 0, !dbg !154
  br i1 %470, label %condition_body288, label %continue279, !dbg !154

condition_body293:                                ; preds = %condition_body288
  %load_FillHead294 = load i16, ptr %FillHead, align 2, !dbg !193
  %471 = sext i16 %load_FillHead294 to i32, !dbg !193
  %tmpVar295 = sub i32 %471, 6, !dbg !193
  %472 = trunc i32 %tmpVar295 to i16, !dbg !193
  store i16 %472, ptr %FillHead, align 2, !dbg !193
  br label %continue290, !dbg !194

else289:                                          ; preds = %condition_body288
  store i16 0, ptr %FillHead, align 2, !dbg !195
  br label %continue290, !dbg !194

continue290:                                      ; preds = %else289, %condition_body293
  br label %continue279, !dbg !196
}

define void @PLC_PRG(ptr %0) !dbg !197 {
entry:
    #dbg_declare(ptr %0, !201, !DIExpression(), !202)
  %PumpRate = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 0
  %ValvePos = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 1
  %PipeTemp = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 2
  %BackPressure = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 3
  %FeedConc = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 4
  %CoolantRate = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 5
  %Cmd = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 6
  %Ctrl = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 7
  %1 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 1, !dbg !202
  %load_PumpRate = load i16, ptr %PumpRate, align 2, !dbg !202
  store i16 %load_PumpRate, ptr %1, align 2, !dbg !202
  %2 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 2, !dbg !202
  %load_ValvePos = load i16, ptr %ValvePos, align 2, !dbg !202
  store i16 %load_ValvePos, ptr %2, align 2, !dbg !202
  %3 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 3, !dbg !202
  %load_PipeTemp = load i16, ptr %PipeTemp, align 2, !dbg !202
  store i16 %load_PipeTemp, ptr %3, align 2, !dbg !202
  %4 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 4, !dbg !202
  %load_BackPressure = load i16, ptr %BackPressure, align 2, !dbg !202
  store i16 %load_BackPressure, ptr %4, align 2, !dbg !202
  %5 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 5, !dbg !202
  %load_FeedConc = load i16, ptr %FeedConc, align 2, !dbg !202
  store i16 %load_FeedConc, ptr %5, align 2, !dbg !202
  %6 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 6, !dbg !202
  %load_CoolantRate = load i16, ptr %CoolantRate, align 2, !dbg !202
  store i16 %load_CoolantRate, ptr %6, align 2, !dbg !202
  %7 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 7, !dbg !202
  %load_Cmd = load i8, ptr %Cmd, align 1, !dbg !202
  store i8 %load_Cmd, ptr %7, align 1, !dbg !202
  call void @PipelineCtrl(ptr %Ctrl), !dbg !202
  ret void, !dbg !203
}

define void @PLC_PRG__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !77
  store ptr %0, ptr %self, align 8, !dbg !77
  %deref = load ptr, ptr %self, align 8, !dbg !77
  %PumpRate = getelementptr inbounds nuw %PLC_PRG, ptr %deref, i32 0, i32 0, !dbg !77
  store i16 0, ptr %PumpRate, align 2, !dbg !77
  %deref1 = load ptr, ptr %self, align 8, !dbg !77
  %ValvePos = getelementptr inbounds nuw %PLC_PRG, ptr %deref1, i32 0, i32 1, !dbg !77
  store i16 0, ptr %ValvePos, align 2, !dbg !77
  %deref2 = load ptr, ptr %self, align 8, !dbg !77
  %PipeTemp = getelementptr inbounds nuw %PLC_PRG, ptr %deref2, i32 0, i32 2, !dbg !77
  store i16 0, ptr %PipeTemp, align 2, !dbg !77
  %deref3 = load ptr, ptr %self, align 8, !dbg !77
  %BackPressure = getelementptr inbounds nuw %PLC_PRG, ptr %deref3, i32 0, i32 3, !dbg !77
  store i16 0, ptr %BackPressure, align 2, !dbg !77
  %deref4 = load ptr, ptr %self, align 8, !dbg !77
  %FeedConc = getelementptr inbounds nuw %PLC_PRG, ptr %deref4, i32 0, i32 4, !dbg !77
  store i16 0, ptr %FeedConc, align 2, !dbg !77
  %deref5 = load ptr, ptr %self, align 8, !dbg !77
  %CoolantRate = getelementptr inbounds nuw %PLC_PRG, ptr %deref5, i32 0, i32 5, !dbg !77
  store i16 0, ptr %CoolantRate, align 2, !dbg !77
  %deref6 = load ptr, ptr %self, align 8, !dbg !77
  %Cmd = getelementptr inbounds nuw %PLC_PRG, ptr %deref6, i32 0, i32 6, !dbg !77
  store i8 0, ptr %Cmd, align 1, !dbg !77
  %deref7 = load ptr, ptr %self, align 8, !dbg !77
  %Ctrl = getelementptr inbounds nuw %PLC_PRG, ptr %deref7, i32 0, i32 7, !dbg !77
  call void @PipelineCtrl__ctor(ptr %Ctrl), !dbg !77
  ret void, !dbg !77
}

define void @PipelineCtrl__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !77
  store ptr %0, ptr %self, align 8, !dbg !77
  %deref = load ptr, ptr %self, align 8, !dbg !77
  %__vtable = getelementptr inbounds nuw %PipelineCtrl, ptr %deref, i32 0, i32 0, !dbg !77
  call void @__PipelineCtrl___vtable__ctor(ptr %__vtable), !dbg !77
  %deref1 = load ptr, ptr %self, align 8, !dbg !77
  %Phase = getelementptr inbounds nuw %PipelineCtrl, ptr %deref1, i32 0, i32 9, !dbg !77
  store i8 0, ptr %Phase, align 1, !dbg !77
  %deref2 = load ptr, ptr %self, align 8, !dbg !77
  %CycleCount = getelementptr inbounds nuw %PipelineCtrl, ptr %deref2, i32 0, i32 10, !dbg !77
  store i16 0, ptr %CycleCount, align 2, !dbg !77
  %deref3 = load ptr, ptr %self, align 8, !dbg !77
  %PrimeCycles = getelementptr inbounds nuw %PipelineCtrl, ptr %deref3, i32 0, i32 11, !dbg !77
  store i16 0, ptr %PrimeCycles, align 2, !dbg !77
  %deref4 = load ptr, ptr %self, align 8, !dbg !77
  %PrimeScore = getelementptr inbounds nuw %PipelineCtrl, ptr %deref4, i32 0, i32 12, !dbg !77
  store i16 0, ptr %PrimeScore, align 2, !dbg !77
  %deref5 = load ptr, ptr %self, align 8, !dbg !77
  %FluxScore = getelementptr inbounds nuw %PipelineCtrl, ptr %deref5, i32 0, i32 13, !dbg !77
  store i16 0, ptr %FluxScore, align 2, !dbg !77
  %deref6 = load ptr, ptr %self, align 8, !dbg !77
  %FluxSum = getelementptr inbounds nuw %PipelineCtrl, ptr %deref6, i32 0, i32 14, !dbg !77
  store i16 0, ptr %FluxSum, align 2, !dbg !77
  %deref7 = load ptr, ptr %self, align 8, !dbg !77
  %FlowAccum = getelementptr inbounds nuw %PipelineCtrl, ptr %deref7, i32 0, i32 15, !dbg !77
  store i16 0, ptr %FlowAccum, align 2, !dbg !77
  %deref8 = load ptr, ptr %self, align 8, !dbg !77
  %PressAccum = getelementptr inbounds nuw %PipelineCtrl, ptr %deref8, i32 0, i32 16, !dbg !77
  store i16 0, ptr %PressAccum, align 2, !dbg !77
  %deref9 = load ptr, ptr %self, align 8, !dbg !77
  %TempAccum = getelementptr inbounds nuw %PipelineCtrl, ptr %deref9, i32 0, i32 17, !dbg !77
  store i16 0, ptr %TempAccum, align 2, !dbg !77
  %deref10 = load ptr, ptr %self, align 8, !dbg !77
  %PhaseCounter = getelementptr inbounds nuw %PipelineCtrl, ptr %deref10, i32 0, i32 18, !dbg !77
  store i16 0, ptr %PhaseCounter, align 2, !dbg !77
  %deref11 = load ptr, ptr %self, align 8, !dbg !77
  %FillHead = getelementptr inbounds nuw %PipelineCtrl, ptr %deref11, i32 0, i32 19, !dbg !77
  store i16 0, ptr %FillHead, align 2, !dbg !77
  %deref12 = load ptr, ptr %self, align 8, !dbg !77
  %Buffer = getelementptr inbounds nuw %PipelineCtrl, ptr %deref12, i32 0, i32 20, !dbg !77
  call void @__PipelineCtrl_Buffer__ctor(ptr %Buffer), !dbg !77
  %deref13 = load ptr, ptr %self, align 8, !dbg !77
  %PVsum = getelementptr inbounds nuw %PipelineCtrl, ptr %deref13, i32 0, i32 21, !dbg !77
  store i16 0, ptr %PVsum, align 2, !dbg !77
  %deref14 = load ptr, ptr %self, align 8, !dbg !77
  %__vtable15 = getelementptr inbounds nuw %PipelineCtrl, ptr %deref14, i32 0, i32 0, !dbg !77
  store ptr @__vtable_PipelineCtrl_instance, ptr %__vtable15, align 8, !dbg !77
  ret void, !dbg !77
}

define void @__PipelineCtrl_Buffer__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !77
  store ptr %0, ptr %self, align 8, !dbg !77
  ret void, !dbg !77
}

define void @__vtable_PipelineCtrl__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !77
  store ptr %0, ptr %self, align 8, !dbg !77
  %deref = load ptr, ptr %self, align 8, !dbg !77
  %__body = getelementptr inbounds nuw %__vtable_PipelineCtrl, ptr %deref, i32 0, i32 0, !dbg !77
  call void @____vtable_PipelineCtrl___body__ctor(ptr %__body), !dbg !77
  %deref1 = load ptr, ptr %self, align 8, !dbg !77
  %__body2 = getelementptr inbounds nuw %__vtable_PipelineCtrl, ptr %deref1, i32 0, i32 0, !dbg !77
  store ptr @PipelineCtrl, ptr %__body2, align 8, !dbg !77
  ret void, !dbg !77
}

define void @__PipelineCtrl___vtable__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !77
  store ptr %0, ptr %self, align 8, !dbg !77
  ret void, !dbg !77
}

define void @____vtable_PipelineCtrl___body__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !77
  store ptr %0, ptr %self, align 8, !dbg !77
  ret void, !dbg !77
}

define void @__unit_program_st__ctor() {
entry:
  call void @__vtable_PipelineCtrl__ctor(ptr @__vtable_PipelineCtrl_instance), !dbg !77
  call void @PLC_PRG__ctor(ptr @PLC_PRG_instance), !dbg !77
  ret void, !dbg !77
}

!llvm.module.flags = !{!56, !57}
!llvm.dbg.cu = !{!58}

!0 = !DIGlobalVariableExpression(var: !1, expr: !DIExpression())
!1 = distinct !DIGlobalVariable(name: "PHASE_IDLE", scope: !2, file: !2, line: 57, type: !3, isLocal: true, isDefinition: true)
!2 = !DIFile(filename: "program.st", directory: "/Users/hamza/Documents/NYUAD/2026_Spring/DirectedStudies/StateFuzzer/rusty/icsquartz/benchmarks/pipeline_controller/src")
!3 = !DIDerivedType(tag: DW_TAG_const_type, baseType: !4)
!4 = !DIBasicType(name: "SINT", size: 8, encoding: DW_ATE_signed, flags: DIFlagPublic)
!5 = !DIGlobalVariableExpression(var: !6, expr: !DIExpression())
!6 = distinct !DIGlobalVariable(name: "PHASE_PRIME", scope: !2, file: !2, line: 58, type: !3, isLocal: true, isDefinition: true)
!7 = !DIGlobalVariableExpression(var: !8, expr: !DIExpression())
!8 = distinct !DIGlobalVariable(name: "PHASE_FLOW", scope: !2, file: !2, line: 59, type: !3, isLocal: true, isDefinition: true)
!9 = !DIGlobalVariableExpression(var: !10, expr: !DIExpression())
!10 = distinct !DIGlobalVariable(name: "PHASE_FILL", scope: !2, file: !2, line: 60, type: !3, isLocal: true, isDefinition: true)
!11 = !DIGlobalVariableExpression(var: !12, expr: !DIExpression())
!12 = distinct !DIGlobalVariable(name: "PLC_PRG", scope: !2, file: !2, line: 63, type: !13, isLocal: true, isDefinition: true)
!13 = !DICompositeType(tag: DW_TAG_structure_type, name: "PLC_PRG", scope: !2, file: !2, line: 63, size: 1536, align: 64, flags: DIFlagPublic, elements: !14, identifier: "PLC_PRG")
!14 = !{!15, !17, !18, !19, !20, !21, !22, !23}
!15 = !DIDerivedType(tag: DW_TAG_member, name: "PumpRate", scope: !2, file: !2, line: 65, baseType: !16, size: 16, align: 16, flags: DIFlagPublic)
!16 = !DIBasicType(name: "INT", size: 16, encoding: DW_ATE_signed, flags: DIFlagPublic)
!17 = !DIDerivedType(tag: DW_TAG_member, name: "ValvePos", scope: !2, file: !2, line: 66, baseType: !16, size: 16, align: 16, offset: 16, flags: DIFlagPublic)
!18 = !DIDerivedType(tag: DW_TAG_member, name: "PipeTemp", scope: !2, file: !2, line: 67, baseType: !16, size: 16, align: 16, offset: 32, flags: DIFlagPublic)
!19 = !DIDerivedType(tag: DW_TAG_member, name: "BackPressure", scope: !2, file: !2, line: 68, baseType: !16, size: 16, align: 16, offset: 48, flags: DIFlagPublic)
!20 = !DIDerivedType(tag: DW_TAG_member, name: "FeedConc", scope: !2, file: !2, line: 69, baseType: !16, size: 16, align: 16, offset: 64, flags: DIFlagPublic)
!21 = !DIDerivedType(tag: DW_TAG_member, name: "CoolantRate", scope: !2, file: !2, line: 70, baseType: !16, size: 16, align: 16, offset: 80, flags: DIFlagPublic)
!22 = !DIDerivedType(tag: DW_TAG_member, name: "Cmd", scope: !2, file: !2, line: 71, baseType: !4, size: 8, align: 8, offset: 96, flags: DIFlagPublic)
!23 = !DIDerivedType(tag: DW_TAG_member, name: "Ctrl", scope: !2, file: !2, line: 74, baseType: !24, size: 1408, align: 64, offset: 128, flags: DIFlagPublic)
!24 = !DICompositeType(tag: DW_TAG_structure_type, name: "PipelineCtrl", scope: !2, file: !2, line: 90, size: 1408, align: 64, flags: DIFlagPublic, elements: !25, identifier: "PipelineCtrl")
!25 = !{!26, !31, !32, !33, !34, !35, !36, !37, !38, !39, !40, !41, !42, !43, !44, !45, !46, !47, !48, !49, !50, !54, !55}
!26 = !DIDerivedType(tag: DW_TAG_member, name: "__vtable", scope: !2, file: !2, baseType: !27, size: 64, align: 64, flags: DIFlagPublic)
!27 = !DIDerivedType(tag: DW_TAG_typedef, name: "__POINTER_TO____PipelineCtrl___vtable", scope: !28, file: !28, baseType: !29, align: 64)
!28 = !DIFile(filename: "/Users/hamza/Documents/NYUAD/2026_Spring/DirectedStudies/StateFuzzer/rusty/icsquartz/benchmarks/pipeline_controller/src/program.st", directory: "")
!29 = !DIDerivedType(tag: DW_TAG_pointer_type, name: "__PipelineCtrl___vtable", baseType: !30, size: 64, align: 64, dwarfAddressSpace: 1)
!30 = !DIBasicType(name: "__VOID", encoding: DW_ATE_unsigned, flags: DIFlagPublic)
!31 = !DIDerivedType(tag: DW_TAG_member, name: "PumpRate", scope: !2, file: !2, line: 92, baseType: !16, size: 16, align: 16, offset: 64, flags: DIFlagPublic)
!32 = !DIDerivedType(tag: DW_TAG_member, name: "ValvePos", scope: !2, file: !2, line: 93, baseType: !16, size: 16, align: 16, offset: 80, flags: DIFlagPublic)
!33 = !DIDerivedType(tag: DW_TAG_member, name: "PipeTemp", scope: !2, file: !2, line: 94, baseType: !16, size: 16, align: 16, offset: 96, flags: DIFlagPublic)
!34 = !DIDerivedType(tag: DW_TAG_member, name: "BackPressure", scope: !2, file: !2, line: 95, baseType: !16, size: 16, align: 16, offset: 112, flags: DIFlagPublic)
!35 = !DIDerivedType(tag: DW_TAG_member, name: "FeedConc", scope: !2, file: !2, line: 96, baseType: !16, size: 16, align: 16, offset: 128, flags: DIFlagPublic)
!36 = !DIDerivedType(tag: DW_TAG_member, name: "CoolantRate", scope: !2, file: !2, line: 97, baseType: !16, size: 16, align: 16, offset: 144, flags: DIFlagPublic)
!37 = !DIDerivedType(tag: DW_TAG_member, name: "Cmd", scope: !2, file: !2, line: 98, baseType: !4, size: 8, align: 8, offset: 160, flags: DIFlagPublic)
!38 = !DIDerivedType(tag: DW_TAG_member, name: "Status", scope: !2, file: !2, line: 101, baseType: !4, size: 8, align: 8, offset: 168, flags: DIFlagPublic)
!39 = !DIDerivedType(tag: DW_TAG_member, name: "Phase", scope: !2, file: !2, line: 104, baseType: !4, size: 8, align: 8, offset: 176, flags: DIFlagPublic)
!40 = !DIDerivedType(tag: DW_TAG_member, name: "CycleCount", scope: !2, file: !2, line: 105, baseType: !16, size: 16, align: 16, offset: 192, flags: DIFlagPublic)
!41 = !DIDerivedType(tag: DW_TAG_member, name: "PrimeCycles", scope: !2, file: !2, line: 107, baseType: !16, size: 16, align: 16, offset: 208, flags: DIFlagPublic)
!42 = !DIDerivedType(tag: DW_TAG_member, name: "PrimeScore", scope: !2, file: !2, line: 108, baseType: !16, size: 16, align: 16, offset: 224, flags: DIFlagPublic)
!43 = !DIDerivedType(tag: DW_TAG_member, name: "FluxScore", scope: !2, file: !2, line: 110, baseType: !16, size: 16, align: 16, offset: 240, flags: DIFlagPublic)
!44 = !DIDerivedType(tag: DW_TAG_member, name: "FluxSum", scope: !2, file: !2, line: 111, baseType: !16, size: 16, align: 16, offset: 256, flags: DIFlagPublic)
!45 = !DIDerivedType(tag: DW_TAG_member, name: "FlowAccum", scope: !2, file: !2, line: 113, baseType: !16, size: 16, align: 16, offset: 272, flags: DIFlagPublic)
!46 = !DIDerivedType(tag: DW_TAG_member, name: "PressAccum", scope: !2, file: !2, line: 114, baseType: !16, size: 16, align: 16, offset: 288, flags: DIFlagPublic)
!47 = !DIDerivedType(tag: DW_TAG_member, name: "TempAccum", scope: !2, file: !2, line: 115, baseType: !16, size: 16, align: 16, offset: 304, flags: DIFlagPublic)
!48 = !DIDerivedType(tag: DW_TAG_member, name: "PhaseCounter", scope: !2, file: !2, line: 116, baseType: !16, size: 16, align: 16, offset: 320, flags: DIFlagPublic)
!49 = !DIDerivedType(tag: DW_TAG_member, name: "FillHead", scope: !2, file: !2, line: 118, baseType: !16, size: 16, align: 16, offset: 336, flags: DIFlagPublic)
!50 = !DIDerivedType(tag: DW_TAG_member, name: "Buffer", scope: !2, file: !2, line: 120, baseType: !51, size: 1024, align: 16, offset: 352, flags: DIFlagPublic)
!51 = !DICompositeType(tag: DW_TAG_array_type, baseType: !16, size: 1024, align: 16, elements: !52)
!52 = !{!53}
!53 = !DISubrange(count: 64, lowerBound: 0)
!54 = !DIDerivedType(tag: DW_TAG_member, name: "PVsum", scope: !2, file: !2, line: 121, baseType: !16, size: 16, align: 16, offset: 1376, flags: DIFlagPublic)
!55 = !DIDerivedType(tag: DW_TAG_member, name: "i", scope: !2, file: !2, line: 122, baseType: !16, size: 16, align: 16, offset: 1392, flags: DIFlagPublic)
!56 = !{i32 2, !"Dwarf Version", i32 5}
!57 = !{i32 2, !"Debug Info Version", i32 3}
!58 = distinct !DICompileUnit(language: DW_LANG_C, file: !28, producer: "RuSTy Structured text Compiler", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, globals: !59, splitDebugInlining: false)
!59 = !{!0, !5, !7, !9, !11}
!60 = distinct !DISubprogram(name: "PipelineCtrl", linkageName: "PipelineCtrl", scope: !2, file: !2, line: 90, type: !61, scopeLine: 125, flags: DIFlagPublic, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !58, retainedNodes: !63)
!61 = !DISubroutineType(flags: DIFlagPublic, types: !62)
!62 = !{null, !24, !16, !16, !16, !16, !16, !16, !4, !4}
!63 = !{!64}
!64 = !DILocalVariable(name: "PipelineCtrl", scope: !60, file: !2, line: 125, type: !24)
!65 = !DILocation(line: 125, scope: !60)
!66 = !DILocation(line: 127, column: 5, scope: !60)
!67 = !DILocation(line: 130, column: 11, scope: !60)
!68 = !DILocation(line: 150, column: 8, scope: !60)
!69 = !DILocation(line: 151, column: 8, scope: !60)
!70 = !DILocation(line: 153, column: 11, scope: !60)
!71 = !DILocation(line: 172, column: 8, scope: !60)
!72 = !DILocation(line: 174, column: 11, scope: !60)
!73 = !DILocation(line: 193, column: 8, scope: !60)
!74 = !DILocation(line: 198, column: 11, scope: !60)
!75 = !DILocation(line: 341, scope: !60)
!76 = !DILocation(line: 343, scope: !60)
!77 = !DILocation(line: 345, scope: !60)
!78 = !DILocation(line: 131, column: 16, scope: !60)
!79 = !DILocation(line: 132, column: 16, scope: !60)
!80 = !DILocation(line: 133, column: 12, scope: !60)
!81 = !DILocation(line: 134, column: 12, scope: !60)
!82 = !DILocation(line: 135, column: 12, scope: !60)
!83 = !DILocation(line: 136, column: 12, scope: !60)
!84 = !DILocation(line: 137, column: 12, scope: !60)
!85 = !DILocation(line: 138, column: 12, scope: !60)
!86 = !DILocation(line: 139, column: 12, scope: !60)
!87 = !DILocation(line: 140, column: 12, scope: !60)
!88 = !DILocation(line: 141, column: 12, scope: !60)
!89 = !DILocation(line: 142, column: 12, scope: !60)
!90 = !DILocation(line: 143, column: 12, scope: !60)
!91 = !DILocation(line: 144, column: 8, scope: !60)
!92 = !DILocation(line: 154, column: 15, scope: !60)
!93 = !DILocation(line: 165, column: 11, scope: !60)
!94 = !DILocation(line: 155, column: 16, scope: !60)
!95 = !DILocation(line: 162, column: 12, scope: !60)
!96 = !DILocation(line: 157, column: 19, scope: !60)
!97 = !DILocation(line: 163, column: 8, scope: !60)
!98 = !DILocation(line: 158, column: 20, scope: !60)
!99 = !DILocation(line: 161, column: 16, scope: !60)
!100 = !DILocation(line: 160, column: 20, scope: !60)
!101 = !DILocation(line: 166, column: 12, scope: !60)
!102 = !DILocation(line: 167, column: 8, scope: !60)
!103 = !DILocation(line: 175, column: 12, scope: !60)
!104 = !DILocation(line: 182, column: 8, scope: !60)
!105 = !DILocation(line: 177, column: 15, scope: !60)
!106 = !DILocation(line: 184, column: 11, scope: !60)
!107 = !DILocation(line: 178, column: 16, scope: !60)
!108 = !DILocation(line: 181, column: 12, scope: !60)
!109 = !DILocation(line: 180, column: 16, scope: !60)
!110 = !DILocation(line: 185, column: 12, scope: !60)
!111 = !DILocation(line: 186, column: 8, scope: !60)
!112 = !DILocation(line: 188, column: 11, scope: !60)
!113 = !DILocation(line: 189, column: 12, scope: !60)
!114 = !DILocation(line: 190, column: 8, scope: !60)
!115 = !DILocation(line: 199, column: 12, scope: !60)
!116 = !DILocation(line: 206, column: 8, scope: !60)
!117 = !DILocation(line: 201, column: 15, scope: !60)
!118 = !DILocation(line: 208, column: 11, scope: !60)
!119 = !DILocation(line: 202, column: 16, scope: !60)
!120 = !DILocation(line: 205, column: 12, scope: !60)
!121 = !DILocation(line: 204, column: 16, scope: !60)
!122 = !DILocation(line: 209, column: 12, scope: !60)
!123 = !DILocation(line: 214, column: 8, scope: !60)
!124 = !DILocation(line: 211, column: 15, scope: !60)
!125 = !DILocation(line: 218, column: 11, scope: !60)
!126 = !DILocation(line: 212, column: 16, scope: !60)
!127 = !DILocation(line: 213, column: 12, scope: !60)
!128 = !DILocation(line: 219, column: 12, scope: !60)
!129 = !DILocation(line: 226, column: 8, scope: !60)
!130 = !DILocation(line: 221, column: 15, scope: !60)
!131 = !DILocation(line: 230, column: 11, scope: !60)
!132 = !DILocation(line: 222, column: 16, scope: !60)
!133 = !DILocation(line: 225, column: 12, scope: !60)
!134 = !DILocation(line: 224, column: 16, scope: !60)
!135 = !DILocation(line: 231, column: 15, scope: !60)
!136 = !DILocation(line: 257, column: 8, scope: !60)
!137 = !DILocation(line: 259, column: 11, scope: !60)
!138 = !DILocation(line: 232, column: 16, scope: !60)
!139 = !DILocation(line: 233, column: 12, scope: !60)
!140 = !DILocation(line: 234, column: 8, scope: !60)
!141 = !DILocation(line: 261, column: 15, scope: !60)
!142 = !DILocation(line: 268, column: 14, scope: !60)
!143 = !DILocation(line: 270, column: 15, scope: !60)
!144 = !DILocation(line: 277, column: 14, scope: !60)
!145 = !DILocation(line: 279, column: 15, scope: !60)
!146 = !DILocation(line: 286, column: 14, scope: !60)
!147 = !DILocation(line: 288, column: 15, scope: !60)
!148 = !DILocation(line: 295, column: 14, scope: !60)
!149 = !DILocation(line: 298, column: 15, scope: !60)
!150 = !DILocation(line: 305, column: 14, scope: !60)
!151 = !DILocation(line: 308, column: 15, scope: !60)
!152 = !DILocation(line: 315, column: 14, scope: !60)
!153 = !DILocation(line: 318, column: 15, scope: !60)
!154 = !DILocation(line: 327, column: 15, scope: !60)
!155 = !DILocation(line: 339, column: 8, scope: !60)
!156 = !DILocation(line: 262, column: 19, scope: !60)
!157 = !DILocation(line: 334, column: 8, scope: !60)
!158 = !DILocation(line: 263, column: 20, scope: !60)
!159 = !DILocation(line: 266, column: 16, scope: !60)
!160 = !DILocation(line: 265, column: 20, scope: !60)
!161 = !DILocation(line: 267, column: 12, scope: !60)
!162 = !DILocation(line: 271, column: 19, scope: !60)
!163 = !DILocation(line: 272, column: 20, scope: !60)
!164 = !DILocation(line: 275, column: 16, scope: !60)
!165 = !DILocation(line: 274, column: 20, scope: !60)
!166 = !DILocation(line: 276, column: 12, scope: !60)
!167 = !DILocation(line: 280, column: 19, scope: !60)
!168 = !DILocation(line: 281, column: 20, scope: !60)
!169 = !DILocation(line: 284, column: 16, scope: !60)
!170 = !DILocation(line: 283, column: 20, scope: !60)
!171 = !DILocation(line: 285, column: 12, scope: !60)
!172 = !DILocation(line: 289, column: 19, scope: !60)
!173 = !DILocation(line: 290, column: 20, scope: !60)
!174 = !DILocation(line: 293, column: 16, scope: !60)
!175 = !DILocation(line: 292, column: 20, scope: !60)
!176 = !DILocation(line: 294, column: 12, scope: !60)
!177 = !DILocation(line: 299, column: 19, scope: !60)
!178 = !DILocation(line: 300, column: 20, scope: !60)
!179 = !DILocation(line: 303, column: 16, scope: !60)
!180 = !DILocation(line: 302, column: 20, scope: !60)
!181 = !DILocation(line: 304, column: 12, scope: !60)
!182 = !DILocation(line: 309, column: 19, scope: !60)
!183 = !DILocation(line: 310, column: 20, scope: !60)
!184 = !DILocation(line: 313, column: 16, scope: !60)
!185 = !DILocation(line: 312, column: 20, scope: !60)
!186 = !DILocation(line: 314, column: 12, scope: !60)
!187 = !DILocation(line: 319, column: 19, scope: !60)
!188 = !DILocation(line: 320, column: 20, scope: !60)
!189 = !DILocation(line: 323, column: 16, scope: !60)
!190 = !DILocation(line: 322, column: 20, scope: !60)
!191 = !DILocation(line: 324, column: 12, scope: !60)
!192 = !DILocation(line: 328, column: 19, scope: !60)
!193 = !DILocation(line: 329, column: 20, scope: !60)
!194 = !DILocation(line: 332, column: 16, scope: !60)
!195 = !DILocation(line: 331, column: 20, scope: !60)
!196 = !DILocation(line: 333, column: 12, scope: !60)
!197 = distinct !DISubprogram(name: "PLC_PRG", linkageName: "PLC_PRG", scope: !2, file: !2, line: 63, type: !198, scopeLine: 77, flags: DIFlagPublic, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !58, retainedNodes: !200)
!198 = !DISubroutineType(flags: DIFlagPublic, types: !199)
!199 = !{null, !13, !16, !16, !16, !16, !16, !16, !4}
!200 = !{!201}
!201 = !DILocalVariable(name: "PLC_PRG", scope: !197, file: !2, line: 77, type: !13)
!202 = !DILocation(line: 77, scope: !197)
!203 = !DILocation(line: 87, scope: !197)
