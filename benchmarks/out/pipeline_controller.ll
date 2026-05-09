; ModuleID = '/tmp/.tmpwBVS5I/benchmarks/pipeline_controller.st.ll'
source_filename = "/workspaces/ICSPrism/benchmarks/pipeline_controller.st"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%__vtable_PipelineCtrl = type { ptr }
%PLC_PRG = type { i16, i16, i16, i16, i16, i16, i8, %PipelineCtrl }
%PipelineCtrl = type { ptr, i16, i16, i16, i16, i16, i16, i8, i8, i8, i16, i16, i16, i16, i16, i16, i16, i16, i16, i16, [64 x i16], i16, i16 }

@PHASE_IDLE = unnamed_addr constant i8 0, !dbg !0
@PHASE_PRIME = unnamed_addr constant i8 1, !dbg !5
@PHASE_FLOW = unnamed_addr constant i8 2, !dbg !7
@PHASE_FILL = unnamed_addr constant i8 3, !dbg !9
@__vtable_PipelineCtrl_instance = global %__vtable_PipelineCtrl zeroinitializer
@PLC_PRG_instance = global %PLC_PRG zeroinitializer, !dbg !11
@llvm.global_ctors = appending global [1 x { i32, ptr, ptr }] [{ i32, ptr, ptr } { i32 65535, ptr @__unit_pipeline_controller_st__ctor, ptr null }]

define void @PipelineCtrl(ptr %0) !dbg !59 {
entry:
    #dbg_declare(ptr %0, !63, !DIExpression(), !64)
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
  %load_CycleCount = load i16, ptr %CycleCount, align 2, !dbg !64
  %1 = sext i16 %load_CycleCount to i32, !dbg !64
  %tmpVar = add i32 %1, 1, !dbg !64
  %2 = trunc i32 %tmpVar to i16, !dbg !64
  store i16 %2, ptr %CycleCount, align 2, !dbg !64
  %load_Phase = load i8, ptr %Phase, align 1, !dbg !64
  %ran_once_0 = alloca i8, align 1
  %is_incrementing_0 = alloca i8, align 1
  switch i8 %load_Phase, label %else [
    i8 0, label %case
    i8 1, label %case23
    i8 2, label %case52
    i8 3, label %case84
  ], !dbg !65

case:                                             ; preds = %entry
  %load_Cmd = load i8, ptr %Cmd, align 1, !dbg !66
  %3 = sext i8 %load_Cmd to i32, !dbg !66
  %tmpVar2 = icmp eq i32 %3, 1, !dbg !66
  %4 = zext i1 %tmpVar2 to i8, !dbg !66
  %5 = icmp ne i8 %4, 0, !dbg !66
  br i1 %5, label %condition_body, label %continue1, !dbg !66

case23:                                           ; preds = %entry
  %load_PrimeCycles = load i16, ptr %PrimeCycles, align 2, !dbg !67
  %6 = sext i16 %load_PrimeCycles to i32, !dbg !67
  %tmpVar24 = add i32 %6, 1, !dbg !67
  %7 = trunc i32 %tmpVar24 to i16, !dbg !67
  store i16 %7, ptr %PrimeCycles, align 2, !dbg !67
  %load_PumpRate = load i16, ptr %PumpRate, align 2, !dbg !68
  %8 = sext i16 %load_PumpRate to i32, !dbg !68
  %load_BackPressure = load i16, ptr %BackPressure, align 2, !dbg !68
  %9 = sext i16 %load_BackPressure to i32, !dbg !68
  %tmpVar25 = add i32 %8, %9, !dbg !68
  %10 = trunc i32 %tmpVar25 to i16, !dbg !68
  store i16 %10, ptr %PVsum, align 2, !dbg !68
  %load_PrimeCycles27 = load i16, ptr %PrimeCycles, align 2, !dbg !69
  %11 = sext i16 %load_PrimeCycles27 to i32, !dbg !69
  %tmpVar28 = srem i32 %11, 3, !dbg !69
  %tmpVar29 = icmp eq i32 %tmpVar28, 0, !dbg !69
  %12 = zext i1 %tmpVar29 to i8, !dbg !69
  %13 = icmp ne i8 %12, 0, !dbg !69
  br i1 %13, label %condition_body30, label %continue26, !dbg !69

case52:                                           ; preds = %entry
  %load_PipeTemp = load i16, ptr %PipeTemp, align 2, !dbg !70
  %14 = sext i16 %load_PipeTemp to i32, !dbg !70
  %load_CoolantRate = load i16, ptr %CoolantRate, align 2, !dbg !70
  %15 = sext i16 %load_CoolantRate to i32, !dbg !70
  %tmpVar53 = add i32 %14, %15, !dbg !70
  %16 = trunc i32 %tmpVar53 to i16, !dbg !70
  store i16 %16, ptr %FluxSum, align 2, !dbg !70
  %load_FluxSum = load i16, ptr %FluxSum, align 2, !dbg !71
  %17 = sext i16 %load_FluxSum to i32, !dbg !71
  %tmpVar56 = icmp sge i32 %17, 80, !dbg !71
  %18 = zext i1 %tmpVar56 to i8, !dbg !71
  %19 = icmp ne i8 %18, 0, !dbg !71
  %load_FluxSum57 = load i16, ptr %FluxSum, align 2, !dbg !71
  %20 = sext i16 %load_FluxSum57 to i32, !dbg !71
  %tmpVar58 = icmp sle i32 %20, 160, !dbg !71
  %21 = zext i1 %tmpVar58 to i8, !dbg !71
  %22 = icmp ne i8 %21, 0, !dbg !71
  %23 = and i1 %19, %22, !dbg !71
  %24 = zext i1 %23 to i8, !dbg !71
  %25 = icmp ne i8 %24, 0, !dbg !71
  %load_FeedConc = load i16, ptr %FeedConc, align 2, !dbg !71
  %26 = sext i16 %load_FeedConc to i32, !dbg !71
  %tmpVar59 = icmp sge i32 %26, 20, !dbg !71
  %27 = zext i1 %tmpVar59 to i8, !dbg !71
  %28 = icmp ne i8 %27, 0, !dbg !71
  %29 = and i1 %25, %28, !dbg !71
  %30 = zext i1 %29 to i8, !dbg !71
  %31 = icmp ne i8 %30, 0, !dbg !71
  %load_FeedConc60 = load i16, ptr %FeedConc, align 2, !dbg !71
  %32 = sext i16 %load_FeedConc60 to i32, !dbg !71
  %tmpVar61 = icmp sle i32 %32, 70, !dbg !71
  %33 = zext i1 %tmpVar61 to i8, !dbg !71
  %34 = icmp ne i8 %33, 0, !dbg !71
  %35 = and i1 %31, %34, !dbg !71
  %36 = zext i1 %35 to i8, !dbg !71
  %37 = icmp ne i8 %36, 0, !dbg !71
  br i1 %37, label %condition_body62, label %else54, !dbg !71

case84:                                           ; preds = %entry
  %load_PhaseCounter = load i16, ptr %PhaseCounter, align 2, !dbg !72
  %38 = sext i16 %load_PhaseCounter to i32, !dbg !72
  %tmpVar85 = add i32 %38, 1, !dbg !72
  %39 = trunc i32 %tmpVar85 to i16, !dbg !72
  store i16 %39, ptr %PhaseCounter, align 2, !dbg !72
  %load_PumpRate88 = load i16, ptr %PumpRate, align 2, !dbg !73
  %40 = sext i16 %load_PumpRate88 to i32, !dbg !73
  %tmpVar89 = icmp sge i32 %40, 40, !dbg !73
  %41 = zext i1 %tmpVar89 to i8, !dbg !73
  %42 = icmp ne i8 %41, 0, !dbg !73
  %load_PumpRate90 = load i16, ptr %PumpRate, align 2, !dbg !73
  %43 = sext i16 %load_PumpRate90 to i32, !dbg !73
  %tmpVar91 = icmp sle i32 %43, 90, !dbg !73
  %44 = zext i1 %tmpVar91 to i8, !dbg !73
  %45 = icmp ne i8 %44, 0, !dbg !73
  %46 = and i1 %42, %45, !dbg !73
  %47 = zext i1 %46 to i8, !dbg !73
  %48 = icmp ne i8 %47, 0, !dbg !73
  br i1 %48, label %condition_body92, label %else86, !dbg !73

else:                                             ; preds = %entry
  br label %continue, !dbg !74

continue:                                         ; preds = %continue148, %continue80, %continue48, %continue1, %else
  %load_Phase323 = load i8, ptr %Phase, align 1, !dbg !75
  store i8 %load_Phase323, ptr %Status, align 1, !dbg !75
  ret void, !dbg !76

condition_body:                                   ; preds = %case
  store i8 0, ptr %ran_once_0, align 1, !dbg !66
  store i8 0, ptr %is_incrementing_0, align 1, !dbg !66
  store i16 0, ptr %i, align 2, !dbg !77
  store i8 1, ptr %is_incrementing_0, align 1, !dbg !78
  br label %while_body, !dbg !78

continue1:                                        ; preds = %continue3, %case
  br label %continue, !dbg !74

while_body:                                       ; preds = %continue8, %condition_body
  %load_ran_once_0 = load i8, ptr %ran_once_0, align 1, !dbg !78
  %49 = icmp ne i8 %load_ran_once_0, 0, !dbg !78
  br i1 %49, label %condition_body5, label %continue4, !dbg !78

continue3:                                        ; preds = %condition_body17, %condition_body13
  store i16 0, ptr %PrimeCycles, align 2, !dbg !79
  store i16 0, ptr %PrimeScore, align 2, !dbg !80
  store i16 0, ptr %FluxScore, align 2, !dbg !81
  store i16 0, ptr %FlowAccum, align 2, !dbg !82
  store i16 0, ptr %PressAccum, align 2, !dbg !83
  store i16 0, ptr %TempAccum, align 2, !dbg !84
  store i16 0, ptr %PhaseCounter, align 2, !dbg !85
  store i16 0, ptr %FillHead, align 2, !dbg !86
  store i16 0, ptr %PVsum, align 2, !dbg !87
  store i8 1, ptr %Phase, align 1, !dbg !88
  br label %continue1, !dbg !89

condition_body5:                                  ; preds = %while_body
  %load_i = load i16, ptr %i, align 2, !dbg !77
  %50 = sext i16 %load_i to i32, !dbg !77
  %tmpVar6 = add i32 %50, 1, !dbg !77
  %51 = trunc i32 %tmpVar6 to i16, !dbg !77
  store i16 %51, ptr %i, align 2, !dbg !77
  br label %continue4, !dbg !78

continue4:                                        ; preds = %condition_body5, %while_body
  store i8 1, ptr %ran_once_0, align 1, !dbg !78
  %load_is_incrementing_0 = load i8, ptr %is_incrementing_0, align 1, !dbg !78
  %52 = icmp ne i8 %load_is_incrementing_0, 0, !dbg !78
  br i1 %52, label %condition_body9, label %else7, !dbg !78

condition_body9:                                  ; preds = %continue4
  %load_i11 = load i16, ptr %i, align 2, !dbg !77
  %53 = sext i16 %load_i11 to i32, !dbg !77
  %tmpVar12 = icmp sgt i32 %53, 63, !dbg !77
  %54 = zext i1 %tmpVar12 to i8, !dbg !77
  %55 = icmp ne i8 %54, 0, !dbg !77
  br i1 %55, label %condition_body13, label %continue10, !dbg !77

else7:                                            ; preds = %continue4
  %load_i15 = load i16, ptr %i, align 2, !dbg !77
  %56 = sext i16 %load_i15 to i32, !dbg !77
  %tmpVar16 = icmp slt i32 %56, 63, !dbg !77
  %57 = zext i1 %tmpVar16 to i8, !dbg !77
  %58 = icmp ne i8 %57, 0, !dbg !77
  br i1 %58, label %condition_body17, label %continue14, !dbg !77

continue8:                                        ; preds = %continue14, %continue10
  %load_i19 = load i16, ptr %i, align 2, !dbg !90
  %59 = sext i16 %load_i19 to i32, !dbg !90
  %tmpVar20 = mul i32 1, %59, !dbg !90
  %tmpVar21 = add i32 %tmpVar20, 0, !dbg !90
  %tmpVar22 = getelementptr inbounds [64 x i16], ptr %Buffer, i32 0, i32 %tmpVar21, !dbg !90
  store i16 0, ptr %tmpVar22, align 2, !dbg !90
  br label %while_body, !dbg !78

condition_body13:                                 ; preds = %condition_body9
  br label %continue3, !dbg !78

buffer_block:                                     ; No predecessors!
  br label %continue10, !dbg !78

continue10:                                       ; preds = %buffer_block, %condition_body9
  br label %continue8, !dbg !78

condition_body17:                                 ; preds = %else7
  br label %continue3, !dbg !78

buffer_block18:                                   ; No predecessors!
  br label %continue14, !dbg !78

continue14:                                       ; preds = %buffer_block18, %else7
  br label %continue8, !dbg !78

condition_body30:                                 ; preds = %case23
  %load_PVsum = load i16, ptr %PVsum, align 2, !dbg !91
  %60 = sext i16 %load_PVsum to i32, !dbg !91
  %tmpVar33 = icmp sge i32 %60, 80, !dbg !91
  %61 = zext i1 %tmpVar33 to i8, !dbg !91
  %62 = icmp ne i8 %61, 0, !dbg !91
  %load_PVsum34 = load i16, ptr %PVsum, align 2, !dbg !91
  %63 = sext i16 %load_PVsum34 to i32, !dbg !91
  %tmpVar35 = icmp sle i32 %63, 160, !dbg !91
  %64 = zext i1 %tmpVar35 to i8, !dbg !91
  %65 = icmp ne i8 %64, 0, !dbg !91
  %66 = and i1 %62, %65, !dbg !91
  %67 = zext i1 %66 to i8, !dbg !91
  %68 = icmp ne i8 %67, 0, !dbg !91
  %load_ValvePos = load i16, ptr %ValvePos, align 2, !dbg !91
  %69 = sext i16 %load_ValvePos to i32, !dbg !91
  %tmpVar36 = icmp sge i32 %69, 15, !dbg !91
  %70 = zext i1 %tmpVar36 to i8, !dbg !91
  %71 = icmp ne i8 %70, 0, !dbg !91
  %72 = and i1 %68, %71, !dbg !91
  %73 = zext i1 %72 to i8, !dbg !91
  %74 = icmp ne i8 %73, 0, !dbg !91
  %load_ValvePos37 = load i16, ptr %ValvePos, align 2, !dbg !91
  %75 = sext i16 %load_ValvePos37 to i32, !dbg !91
  %tmpVar38 = icmp sle i32 %75, 60, !dbg !91
  %76 = zext i1 %tmpVar38 to i8, !dbg !91
  %77 = icmp ne i8 %76, 0, !dbg !91
  %78 = and i1 %74, %77, !dbg !91
  %79 = zext i1 %78 to i8, !dbg !91
  %80 = icmp ne i8 %79, 0, !dbg !91
  br i1 %80, label %condition_body39, label %else31, !dbg !91

continue26:                                       ; preds = %continue32, %case23
  %load_PrimeScore49 = load i16, ptr %PrimeScore, align 2, !dbg !92
  %81 = sext i16 %load_PrimeScore49 to i32, !dbg !92
  %tmpVar50 = icmp sge i32 %81, 8, !dbg !92
  %82 = zext i1 %tmpVar50 to i8, !dbg !92
  %83 = icmp ne i8 %82, 0, !dbg !92
  br i1 %83, label %condition_body51, label %continue48, !dbg !92

condition_body39:                                 ; preds = %condition_body30
  %load_PrimeScore = load i16, ptr %PrimeScore, align 2, !dbg !93
  %84 = sext i16 %load_PrimeScore to i32, !dbg !93
  %tmpVar40 = add i32 %84, 1, !dbg !93
  %85 = trunc i32 %tmpVar40 to i16, !dbg !93
  store i16 %85, ptr %PrimeScore, align 2, !dbg !93
  br label %continue32, !dbg !94

else31:                                           ; preds = %condition_body30
  %load_PrimeScore43 = load i16, ptr %PrimeScore, align 2, !dbg !95
  %86 = sext i16 %load_PrimeScore43 to i32, !dbg !95
  %tmpVar44 = icmp sgt i32 %86, 1, !dbg !95
  %87 = zext i1 %tmpVar44 to i8, !dbg !95
  %88 = icmp ne i8 %87, 0, !dbg !95
  br i1 %88, label %condition_body45, label %else41, !dbg !95

continue32:                                       ; preds = %continue42, %condition_body39
  br label %continue26, !dbg !96

condition_body45:                                 ; preds = %else31
  %load_PrimeScore46 = load i16, ptr %PrimeScore, align 2, !dbg !97
  %89 = sext i16 %load_PrimeScore46 to i32, !dbg !97
  %tmpVar47 = sub i32 %89, 2, !dbg !97
  %90 = trunc i32 %tmpVar47 to i16, !dbg !97
  store i16 %90, ptr %PrimeScore, align 2, !dbg !97
  br label %continue42, !dbg !98

else41:                                           ; preds = %else31
  store i16 0, ptr %PrimeScore, align 2, !dbg !99
  br label %continue42, !dbg !98

continue42:                                       ; preds = %else41, %condition_body45
  br label %continue32, !dbg !94

condition_body51:                                 ; preds = %continue26
  store i8 2, ptr %Phase, align 1, !dbg !100
  br label %continue48, !dbg !101

continue48:                                       ; preds = %condition_body51, %continue26
  br label %continue, !dbg !74

condition_body62:                                 ; preds = %case52
  %load_FluxScore = load i16, ptr %FluxScore, align 2, !dbg !102
  %91 = sext i16 %load_FluxScore to i32, !dbg !102
  %tmpVar63 = add i32 %91, 1, !dbg !102
  %92 = trunc i32 %tmpVar63 to i16, !dbg !102
  store i16 %92, ptr %FluxScore, align 2, !dbg !102
  br label %continue55, !dbg !103

else54:                                           ; preds = %case52
  %load_FluxScore66 = load i16, ptr %FluxScore, align 2, !dbg !104
  %93 = sext i16 %load_FluxScore66 to i32, !dbg !104
  %tmpVar67 = icmp sgt i32 %93, 1, !dbg !104
  %94 = zext i1 %tmpVar67 to i8, !dbg !104
  %95 = icmp ne i8 %94, 0, !dbg !104
  br i1 %95, label %condition_body68, label %else64, !dbg !104

continue55:                                       ; preds = %continue65, %condition_body62
  %load_CycleCount72 = load i16, ptr %CycleCount, align 2, !dbg !105
  %96 = sext i16 %load_CycleCount72 to i32, !dbg !105
  %tmpVar73 = srem i32 %96, 11, !dbg !105
  %tmpVar74 = icmp eq i32 %tmpVar73, 0, !dbg !105
  %97 = zext i1 %tmpVar74 to i8, !dbg !105
  %98 = icmp ne i8 %97, 0, !dbg !105
  %load_FluxScore75 = load i16, ptr %FluxScore, align 2, !dbg !105
  %99 = sext i16 %load_FluxScore75 to i32, !dbg !105
  %tmpVar76 = icmp sgt i32 %99, 0, !dbg !105
  %100 = zext i1 %tmpVar76 to i8, !dbg !105
  %101 = icmp ne i8 %100, 0, !dbg !105
  %102 = and i1 %98, %101, !dbg !105
  %103 = zext i1 %102 to i8, !dbg !105
  %104 = icmp ne i8 %103, 0, !dbg !105
  br i1 %104, label %condition_body77, label %continue71, !dbg !105

condition_body68:                                 ; preds = %else54
  %load_FluxScore69 = load i16, ptr %FluxScore, align 2, !dbg !106
  %105 = sext i16 %load_FluxScore69 to i32, !dbg !106
  %tmpVar70 = sub i32 %105, 2, !dbg !106
  %106 = trunc i32 %tmpVar70 to i16, !dbg !106
  store i16 %106, ptr %FluxScore, align 2, !dbg !106
  br label %continue65, !dbg !107

else64:                                           ; preds = %else54
  store i16 0, ptr %FluxScore, align 2, !dbg !108
  br label %continue65, !dbg !107

continue65:                                       ; preds = %else64, %condition_body68
  br label %continue55, !dbg !103

condition_body77:                                 ; preds = %continue55
  %load_FluxScore78 = load i16, ptr %FluxScore, align 2, !dbg !109
  %107 = sext i16 %load_FluxScore78 to i32, !dbg !109
  %tmpVar79 = sdiv i32 %107, 2, !dbg !109
  %108 = trunc i32 %tmpVar79 to i16, !dbg !109
  store i16 %108, ptr %FluxScore, align 2, !dbg !109
  br label %continue71, !dbg !110

continue71:                                       ; preds = %condition_body77, %continue55
  %load_FluxScore81 = load i16, ptr %FluxScore, align 2, !dbg !111
  %109 = sext i16 %load_FluxScore81 to i32, !dbg !111
  %tmpVar82 = icmp sge i32 %109, 8, !dbg !111
  %110 = zext i1 %tmpVar82 to i8, !dbg !111
  %111 = icmp ne i8 %110, 0, !dbg !111
  br i1 %111, label %condition_body83, label %continue80, !dbg !111

condition_body83:                                 ; preds = %continue71
  store i8 3, ptr %Phase, align 1, !dbg !112
  br label %continue80, !dbg !113

continue80:                                       ; preds = %condition_body83, %continue71
  br label %continue, !dbg !74

condition_body92:                                 ; preds = %case84
  %load_FlowAccum = load i16, ptr %FlowAccum, align 2, !dbg !114
  %112 = sext i16 %load_FlowAccum to i32, !dbg !114
  %tmpVar93 = add i32 %112, 1, !dbg !114
  %113 = trunc i32 %tmpVar93 to i16, !dbg !114
  store i16 %113, ptr %FlowAccum, align 2, !dbg !114
  br label %continue87, !dbg !115

else86:                                           ; preds = %case84
  %load_FlowAccum96 = load i16, ptr %FlowAccum, align 2, !dbg !116
  %114 = sext i16 %load_FlowAccum96 to i32, !dbg !116
  %tmpVar97 = icmp sgt i32 %114, 1, !dbg !116
  %115 = zext i1 %tmpVar97 to i8, !dbg !116
  %116 = icmp ne i8 %115, 0, !dbg !116
  br i1 %116, label %condition_body98, label %else94, !dbg !116

continue87:                                       ; preds = %continue95, %condition_body92
  %load_BackPressure103 = load i16, ptr %BackPressure, align 2, !dbg !117
  %117 = sext i16 %load_BackPressure103 to i32, !dbg !117
  %tmpVar104 = icmp sge i32 %117, 30, !dbg !117
  %118 = zext i1 %tmpVar104 to i8, !dbg !117
  %119 = icmp ne i8 %118, 0, !dbg !117
  %load_BackPressure105 = load i16, ptr %BackPressure, align 2, !dbg !117
  %120 = sext i16 %load_BackPressure105 to i32, !dbg !117
  %tmpVar106 = icmp sle i32 %120, 80, !dbg !117
  %121 = zext i1 %tmpVar106 to i8, !dbg !117
  %122 = icmp ne i8 %121, 0, !dbg !117
  %123 = and i1 %119, %122, !dbg !117
  %124 = zext i1 %123 to i8, !dbg !117
  %125 = icmp ne i8 %124, 0, !dbg !117
  br i1 %125, label %condition_body107, label %else101, !dbg !117

condition_body98:                                 ; preds = %else86
  %load_FlowAccum99 = load i16, ptr %FlowAccum, align 2, !dbg !118
  %126 = sext i16 %load_FlowAccum99 to i32, !dbg !118
  %tmpVar100 = sub i32 %126, 2, !dbg !118
  %127 = trunc i32 %tmpVar100 to i16, !dbg !118
  store i16 %127, ptr %FlowAccum, align 2, !dbg !118
  br label %continue95, !dbg !119

else94:                                           ; preds = %else86
  store i16 0, ptr %FlowAccum, align 2, !dbg !120
  br label %continue95, !dbg !119

continue95:                                       ; preds = %else94, %condition_body98
  br label %continue87, !dbg !115

condition_body107:                                ; preds = %continue87
  %load_PressAccum = load i16, ptr %PressAccum, align 2, !dbg !121
  %128 = sext i16 %load_PressAccum to i32, !dbg !121
  %tmpVar108 = add i32 %128, 1, !dbg !121
  %129 = trunc i32 %tmpVar108 to i16, !dbg !121
  store i16 %129, ptr %PressAccum, align 2, !dbg !121
  br label %continue102, !dbg !122

else101:                                          ; preds = %continue87
  %load_PressAccum110 = load i16, ptr %PressAccum, align 2, !dbg !123
  %130 = sext i16 %load_PressAccum110 to i32, !dbg !123
  %tmpVar111 = icmp sgt i32 %130, 0, !dbg !123
  %131 = zext i1 %tmpVar111 to i8, !dbg !123
  %132 = icmp ne i8 %131, 0, !dbg !123
  br i1 %132, label %condition_body112, label %continue109, !dbg !123

continue102:                                      ; preds = %continue109, %condition_body107
  %load_PipeTemp117 = load i16, ptr %PipeTemp, align 2, !dbg !124
  %133 = sext i16 %load_PipeTemp117 to i32, !dbg !124
  %tmpVar118 = icmp sge i32 %133, 50, !dbg !124
  %134 = zext i1 %tmpVar118 to i8, !dbg !124
  %135 = icmp ne i8 %134, 0, !dbg !124
  %load_PipeTemp119 = load i16, ptr %PipeTemp, align 2, !dbg !124
  %136 = sext i16 %load_PipeTemp119 to i32, !dbg !124
  %tmpVar120 = icmp sle i32 %136, 100, !dbg !124
  %137 = zext i1 %tmpVar120 to i8, !dbg !124
  %138 = icmp ne i8 %137, 0, !dbg !124
  %139 = and i1 %135, %138, !dbg !124
  %140 = zext i1 %139 to i8, !dbg !124
  %141 = icmp ne i8 %140, 0, !dbg !124
  br i1 %141, label %condition_body121, label %else115, !dbg !124

condition_body112:                                ; preds = %else101
  %load_PressAccum113 = load i16, ptr %PressAccum, align 2, !dbg !125
  %142 = sext i16 %load_PressAccum113 to i32, !dbg !125
  %tmpVar114 = sub i32 %142, 1, !dbg !125
  %143 = trunc i32 %tmpVar114 to i16, !dbg !125
  store i16 %143, ptr %PressAccum, align 2, !dbg !125
  br label %continue109, !dbg !126

continue109:                                      ; preds = %condition_body112, %else101
  br label %continue102, !dbg !122

condition_body121:                                ; preds = %continue102
  %load_TempAccum = load i16, ptr %TempAccum, align 2, !dbg !127
  %144 = sext i16 %load_TempAccum to i32, !dbg !127
  %tmpVar122 = add i32 %144, 1, !dbg !127
  %145 = trunc i32 %tmpVar122 to i16, !dbg !127
  store i16 %145, ptr %TempAccum, align 2, !dbg !127
  br label %continue116, !dbg !128

else115:                                          ; preds = %continue102
  %load_TempAccum125 = load i16, ptr %TempAccum, align 2, !dbg !129
  %146 = sext i16 %load_TempAccum125 to i32, !dbg !129
  %tmpVar126 = icmp sgt i32 %146, 1, !dbg !129
  %147 = zext i1 %tmpVar126 to i8, !dbg !129
  %148 = icmp ne i8 %147, 0, !dbg !129
  br i1 %148, label %condition_body127, label %else123, !dbg !129

continue116:                                      ; preds = %continue124, %condition_body121
  %load_FlowAccum131 = load i16, ptr %FlowAccum, align 2, !dbg !130
  %149 = sext i16 %load_FlowAccum131 to i32, !dbg !130
  %tmpVar132 = icmp sgt i32 %149, 6, !dbg !130
  %150 = zext i1 %tmpVar132 to i8, !dbg !130
  %151 = icmp ne i8 %150, 0, !dbg !130
  %load_PressAccum133 = load i16, ptr %PressAccum, align 2, !dbg !130
  %152 = sext i16 %load_PressAccum133 to i32, !dbg !130
  %tmpVar134 = icmp sgt i32 %152, 5, !dbg !130
  %153 = zext i1 %tmpVar134 to i8, !dbg !130
  %154 = icmp ne i8 %153, 0, !dbg !130
  %155 = and i1 %151, %154, !dbg !130
  %156 = zext i1 %155 to i8, !dbg !130
  %157 = icmp ne i8 %156, 0, !dbg !130
  %load_TempAccum135 = load i16, ptr %TempAccum, align 2, !dbg !130
  %158 = sext i16 %load_TempAccum135 to i32, !dbg !130
  %tmpVar136 = icmp sgt i32 %158, 6, !dbg !130
  %159 = zext i1 %tmpVar136 to i8, !dbg !130
  %160 = icmp ne i8 %159, 0, !dbg !130
  %161 = and i1 %157, %160, !dbg !130
  %162 = zext i1 %161 to i8, !dbg !130
  %163 = icmp ne i8 %162, 0, !dbg !130
  br i1 %163, label %condition_body137, label %continue130, !dbg !130

condition_body127:                                ; preds = %else115
  %load_TempAccum128 = load i16, ptr %TempAccum, align 2, !dbg !131
  %164 = sext i16 %load_TempAccum128 to i32, !dbg !131
  %tmpVar129 = sub i32 %164, 2, !dbg !131
  %165 = trunc i32 %tmpVar129 to i16, !dbg !131
  store i16 %165, ptr %TempAccum, align 2, !dbg !131
  br label %continue124, !dbg !132

else123:                                          ; preds = %else115
  store i16 0, ptr %TempAccum, align 2, !dbg !133
  br label %continue124, !dbg !132

continue124:                                      ; preds = %else123, %condition_body127
  br label %continue116, !dbg !128

condition_body137:                                ; preds = %continue116
  %load_PhaseCounter139 = load i16, ptr %PhaseCounter, align 2, !dbg !134
  %166 = sext i16 %load_PhaseCounter139 to i32, !dbg !134
  %tmpVar140 = srem i32 %166, 4, !dbg !134
  %tmpVar141 = icmp eq i32 %tmpVar140, 0, !dbg !134
  %167 = zext i1 %tmpVar141 to i8, !dbg !134
  %168 = icmp ne i8 %167, 0, !dbg !134
  br i1 %168, label %condition_body142, label %continue138, !dbg !134

continue130:                                      ; preds = %continue138, %continue116
  %load_PumpRate144 = load i16, ptr %PumpRate, align 2, !dbg !135
  %169 = sext i16 %load_PumpRate144 to i32, !dbg !135
  %load_ValvePos145 = load i16, ptr %ValvePos, align 2, !dbg !135
  %170 = sext i16 %load_ValvePos145 to i32, !dbg !135
  %tmpVar146 = add i32 %169, %170, !dbg !135
  %171 = trunc i32 %tmpVar146 to i16, !dbg !135
  store i16 %171, ptr %PVsum, align 2, !dbg !135
  %load_FillHead149 = load i16, ptr %FillHead, align 2, !dbg !136
  %172 = sext i16 %load_FillHead149 to i32, !dbg !136
  %tmpVar150 = icmp slt i32 %172, 8, !dbg !136
  %173 = zext i1 %tmpVar150 to i8, !dbg !136
  %174 = icmp ne i8 %173, 0, !dbg !136
  br i1 %174, label %condition_body151, label %else147, !dbg !136

condition_body142:                                ; preds = %condition_body137
  %load_FillHead = load i16, ptr %FillHead, align 2, !dbg !137
  %175 = sext i16 %load_FillHead to i32, !dbg !137
  %tmpVar143 = add i32 %175, 1, !dbg !137
  %176 = trunc i32 %tmpVar143 to i16, !dbg !137
  store i16 %176, ptr %FillHead, align 2, !dbg !137
  br label %continue138, !dbg !138

continue138:                                      ; preds = %condition_body142, %condition_body137
  br label %continue130, !dbg !139

condition_body151:                                ; preds = %continue130
  %load_PVsum153 = load i16, ptr %PVsum, align 2, !dbg !140
  %177 = sext i16 %load_PVsum153 to i32, !dbg !140
  %tmpVar154 = icmp slt i32 %177, 60, !dbg !140
  %178 = zext i1 %tmpVar154 to i8, !dbg !140
  %179 = icmp ne i8 %178, 0, !dbg !140
  %load_PVsum155 = load i16, ptr %PVsum, align 2, !dbg !140
  %180 = sext i16 %load_PVsum155 to i32, !dbg !140
  %tmpVar156 = icmp sgt i32 %180, 90, !dbg !140
  %181 = zext i1 %tmpVar156 to i8, !dbg !140
  %182 = icmp ne i8 %181, 0, !dbg !140
  %183 = or i1 %179, %182, !dbg !140
  %184 = zext i1 %183 to i8, !dbg !140
  %185 = icmp ne i8 %184, 0, !dbg !140
  %load_PipeTemp157 = load i16, ptr %PipeTemp, align 2, !dbg !140
  %186 = sext i16 %load_PipeTemp157 to i32, !dbg !140
  %tmpVar158 = icmp slt i32 %186, 50, !dbg !140
  %187 = zext i1 %tmpVar158 to i8, !dbg !140
  %188 = icmp ne i8 %187, 0, !dbg !140
  %189 = or i1 %185, %188, !dbg !140
  %190 = zext i1 %189 to i8, !dbg !140
  %191 = icmp ne i8 %190, 0, !dbg !140
  %load_PipeTemp159 = load i16, ptr %PipeTemp, align 2, !dbg !140
  %192 = sext i16 %load_PipeTemp159 to i32, !dbg !140
  %tmpVar160 = icmp sgt i32 %192, 65, !dbg !140
  %193 = zext i1 %tmpVar160 to i8, !dbg !140
  %194 = icmp ne i8 %193, 0, !dbg !140
  %195 = or i1 %191, %194, !dbg !140
  %196 = zext i1 %195 to i8, !dbg !140
  %197 = icmp ne i8 %196, 0, !dbg !140
  br i1 %197, label %condition_body161, label %continue152, !dbg !140

else147:                                          ; preds = %continue130
  %load_FillHead171 = load i16, ptr %FillHead, align 2, !dbg !141
  %198 = sext i16 %load_FillHead171 to i32, !dbg !141
  %tmpVar172 = icmp slt i32 %198, 16, !dbg !141
  %199 = zext i1 %tmpVar172 to i8, !dbg !141
  %200 = icmp ne i8 %199, 0, !dbg !141
  br i1 %200, label %condition_body173, label %else169, !dbg !141

continue148:                                      ; preds = %continue170, %continue152
  %load_FillHead318 = load i16, ptr %FillHead, align 2, !dbg !142
  %201 = sext i16 %load_FillHead318 to i32, !dbg !142
  %tmpVar319 = mul i32 1, %201, !dbg !142
  %tmpVar320 = add i32 %tmpVar319, 0, !dbg !142
  %tmpVar321 = getelementptr inbounds [64 x i16], ptr %Buffer, i32 0, i32 %tmpVar320, !dbg !142
  %load_CycleCount322 = load i16, ptr %CycleCount, align 2, !dbg !142
  store i16 %load_CycleCount322, ptr %tmpVar321, align 2, !dbg !142
  br label %continue, !dbg !74

condition_body161:                                ; preds = %condition_body151
  %load_FillHead164 = load i16, ptr %FillHead, align 2, !dbg !143
  %202 = sext i16 %load_FillHead164 to i32, !dbg !143
  %tmpVar165 = icmp sgt i32 %202, 5, !dbg !143
  %203 = zext i1 %tmpVar165 to i8, !dbg !143
  %204 = icmp ne i8 %203, 0, !dbg !143
  br i1 %204, label %condition_body166, label %else162, !dbg !143

continue152:                                      ; preds = %continue163, %condition_body151
  br label %continue148, !dbg !144

condition_body166:                                ; preds = %condition_body161
  %load_FillHead167 = load i16, ptr %FillHead, align 2, !dbg !145
  %205 = sext i16 %load_FillHead167 to i32, !dbg !145
  %tmpVar168 = sub i32 %205, 6, !dbg !145
  %206 = trunc i32 %tmpVar168 to i16, !dbg !145
  store i16 %206, ptr %FillHead, align 2, !dbg !145
  br label %continue163, !dbg !146

else162:                                          ; preds = %condition_body161
  store i16 0, ptr %FillHead, align 2, !dbg !147
  br label %continue163, !dbg !146

continue163:                                      ; preds = %else162, %condition_body166
  br label %continue152, !dbg !148

condition_body173:                                ; preds = %else147
  %load_PVsum175 = load i16, ptr %PVsum, align 2, !dbg !149
  %207 = sext i16 %load_PVsum175 to i32, !dbg !149
  %tmpVar176 = icmp slt i32 %207, 80, !dbg !149
  %208 = zext i1 %tmpVar176 to i8, !dbg !149
  %209 = icmp ne i8 %208, 0, !dbg !149
  %load_PVsum177 = load i16, ptr %PVsum, align 2, !dbg !149
  %210 = sext i16 %load_PVsum177 to i32, !dbg !149
  %tmpVar178 = icmp sgt i32 %210, 110, !dbg !149
  %211 = zext i1 %tmpVar178 to i8, !dbg !149
  %212 = icmp ne i8 %211, 0, !dbg !149
  %213 = or i1 %209, %212, !dbg !149
  %214 = zext i1 %213 to i8, !dbg !149
  %215 = icmp ne i8 %214, 0, !dbg !149
  %load_PipeTemp179 = load i16, ptr %PipeTemp, align 2, !dbg !149
  %216 = sext i16 %load_PipeTemp179 to i32, !dbg !149
  %tmpVar180 = icmp slt i32 %216, 62, !dbg !149
  %217 = zext i1 %tmpVar180 to i8, !dbg !149
  %218 = icmp ne i8 %217, 0, !dbg !149
  %219 = or i1 %215, %218, !dbg !149
  %220 = zext i1 %219 to i8, !dbg !149
  %221 = icmp ne i8 %220, 0, !dbg !149
  %load_PipeTemp181 = load i16, ptr %PipeTemp, align 2, !dbg !149
  %222 = sext i16 %load_PipeTemp181 to i32, !dbg !149
  %tmpVar182 = icmp sgt i32 %222, 77, !dbg !149
  %223 = zext i1 %tmpVar182 to i8, !dbg !149
  %224 = icmp ne i8 %223, 0, !dbg !149
  %225 = or i1 %221, %224, !dbg !149
  %226 = zext i1 %225 to i8, !dbg !149
  %227 = icmp ne i8 %226, 0, !dbg !149
  br i1 %227, label %condition_body183, label %continue174, !dbg !149

else169:                                          ; preds = %else147
  %load_FillHead193 = load i16, ptr %FillHead, align 2, !dbg !150
  %228 = sext i16 %load_FillHead193 to i32, !dbg !150
  %tmpVar194 = icmp slt i32 %228, 24, !dbg !150
  %229 = zext i1 %tmpVar194 to i8, !dbg !150
  %230 = icmp ne i8 %229, 0, !dbg !150
  br i1 %230, label %condition_body195, label %else191, !dbg !150

continue170:                                      ; preds = %continue192, %continue174
  br label %continue148, !dbg !144

condition_body183:                                ; preds = %condition_body173
  %load_FillHead186 = load i16, ptr %FillHead, align 2, !dbg !151
  %231 = sext i16 %load_FillHead186 to i32, !dbg !151
  %tmpVar187 = icmp sgt i32 %231, 5, !dbg !151
  %232 = zext i1 %tmpVar187 to i8, !dbg !151
  %233 = icmp ne i8 %232, 0, !dbg !151
  br i1 %233, label %condition_body188, label %else184, !dbg !151

continue174:                                      ; preds = %continue185, %condition_body173
  br label %continue170, !dbg !144

condition_body188:                                ; preds = %condition_body183
  %load_FillHead189 = load i16, ptr %FillHead, align 2, !dbg !152
  %234 = sext i16 %load_FillHead189 to i32, !dbg !152
  %tmpVar190 = sub i32 %234, 6, !dbg !152
  %235 = trunc i32 %tmpVar190 to i16, !dbg !152
  store i16 %235, ptr %FillHead, align 2, !dbg !152
  br label %continue185, !dbg !153

else184:                                          ; preds = %condition_body183
  store i16 0, ptr %FillHead, align 2, !dbg !154
  br label %continue185, !dbg !153

continue185:                                      ; preds = %else184, %condition_body188
  br label %continue174, !dbg !155

condition_body195:                                ; preds = %else169
  %load_PVsum197 = load i16, ptr %PVsum, align 2, !dbg !156
  %236 = sext i16 %load_PVsum197 to i32, !dbg !156
  %tmpVar198 = icmp slt i32 %236, 70, !dbg !156
  %237 = zext i1 %tmpVar198 to i8, !dbg !156
  %238 = icmp ne i8 %237, 0, !dbg !156
  %load_PVsum199 = load i16, ptr %PVsum, align 2, !dbg !156
  %239 = sext i16 %load_PVsum199 to i32, !dbg !156
  %tmpVar200 = icmp sgt i32 %239, 100, !dbg !156
  %240 = zext i1 %tmpVar200 to i8, !dbg !156
  %241 = icmp ne i8 %240, 0, !dbg !156
  %242 = or i1 %238, %241, !dbg !156
  %243 = zext i1 %242 to i8, !dbg !156
  %244 = icmp ne i8 %243, 0, !dbg !156
  %load_PipeTemp201 = load i16, ptr %PipeTemp, align 2, !dbg !156
  %245 = sext i16 %load_PipeTemp201 to i32, !dbg !156
  %tmpVar202 = icmp slt i32 %245, 72, !dbg !156
  %246 = zext i1 %tmpVar202 to i8, !dbg !156
  %247 = icmp ne i8 %246, 0, !dbg !156
  %248 = or i1 %244, %247, !dbg !156
  %249 = zext i1 %248 to i8, !dbg !156
  %250 = icmp ne i8 %249, 0, !dbg !156
  %load_PipeTemp203 = load i16, ptr %PipeTemp, align 2, !dbg !156
  %251 = sext i16 %load_PipeTemp203 to i32, !dbg !156
  %tmpVar204 = icmp sgt i32 %251, 87, !dbg !156
  %252 = zext i1 %tmpVar204 to i8, !dbg !156
  %253 = icmp ne i8 %252, 0, !dbg !156
  %254 = or i1 %250, %253, !dbg !156
  %255 = zext i1 %254 to i8, !dbg !156
  %256 = icmp ne i8 %255, 0, !dbg !156
  br i1 %256, label %condition_body205, label %continue196, !dbg !156

else191:                                          ; preds = %else169
  %load_FillHead215 = load i16, ptr %FillHead, align 2, !dbg !157
  %257 = sext i16 %load_FillHead215 to i32, !dbg !157
  %tmpVar216 = icmp slt i32 %257, 32, !dbg !157
  %258 = zext i1 %tmpVar216 to i8, !dbg !157
  %259 = icmp ne i8 %258, 0, !dbg !157
  br i1 %259, label %condition_body217, label %else213, !dbg !157

continue192:                                      ; preds = %continue214, %continue196
  br label %continue170, !dbg !144

condition_body205:                                ; preds = %condition_body195
  %load_FillHead208 = load i16, ptr %FillHead, align 2, !dbg !158
  %260 = sext i16 %load_FillHead208 to i32, !dbg !158
  %tmpVar209 = icmp sgt i32 %260, 5, !dbg !158
  %261 = zext i1 %tmpVar209 to i8, !dbg !158
  %262 = icmp ne i8 %261, 0, !dbg !158
  br i1 %262, label %condition_body210, label %else206, !dbg !158

continue196:                                      ; preds = %continue207, %condition_body195
  br label %continue192, !dbg !144

condition_body210:                                ; preds = %condition_body205
  %load_FillHead211 = load i16, ptr %FillHead, align 2, !dbg !159
  %263 = sext i16 %load_FillHead211 to i32, !dbg !159
  %tmpVar212 = sub i32 %263, 6, !dbg !159
  %264 = trunc i32 %tmpVar212 to i16, !dbg !159
  store i16 %264, ptr %FillHead, align 2, !dbg !159
  br label %continue207, !dbg !160

else206:                                          ; preds = %condition_body205
  store i16 0, ptr %FillHead, align 2, !dbg !161
  br label %continue207, !dbg !160

continue207:                                      ; preds = %else206, %condition_body210
  br label %continue196, !dbg !162

condition_body217:                                ; preds = %else191
  %load_PVsum219 = load i16, ptr %PVsum, align 2, !dbg !163
  %265 = sext i16 %load_PVsum219 to i32, !dbg !163
  %tmpVar220 = icmp slt i32 %265, 55, !dbg !163
  %266 = zext i1 %tmpVar220 to i8, !dbg !163
  %267 = icmp ne i8 %266, 0, !dbg !163
  %load_PVsum221 = load i16, ptr %PVsum, align 2, !dbg !163
  %268 = sext i16 %load_PVsum221 to i32, !dbg !163
  %tmpVar222 = icmp sgt i32 %268, 85, !dbg !163
  %269 = zext i1 %tmpVar222 to i8, !dbg !163
  %270 = icmp ne i8 %269, 0, !dbg !163
  %271 = or i1 %267, %270, !dbg !163
  %272 = zext i1 %271 to i8, !dbg !163
  %273 = icmp ne i8 %272, 0, !dbg !163
  %load_PipeTemp223 = load i16, ptr %PipeTemp, align 2, !dbg !163
  %274 = sext i16 %load_PipeTemp223 to i32, !dbg !163
  %tmpVar224 = icmp slt i32 %274, 65, !dbg !163
  %275 = zext i1 %tmpVar224 to i8, !dbg !163
  %276 = icmp ne i8 %275, 0, !dbg !163
  %277 = or i1 %273, %276, !dbg !163
  %278 = zext i1 %277 to i8, !dbg !163
  %279 = icmp ne i8 %278, 0, !dbg !163
  %load_PipeTemp225 = load i16, ptr %PipeTemp, align 2, !dbg !163
  %280 = sext i16 %load_PipeTemp225 to i32, !dbg !163
  %tmpVar226 = icmp sgt i32 %280, 80, !dbg !163
  %281 = zext i1 %tmpVar226 to i8, !dbg !163
  %282 = icmp ne i8 %281, 0, !dbg !163
  %283 = or i1 %279, %282, !dbg !163
  %284 = zext i1 %283 to i8, !dbg !163
  %285 = icmp ne i8 %284, 0, !dbg !163
  br i1 %285, label %condition_body227, label %continue218, !dbg !163

else213:                                          ; preds = %else191
  %load_FillHead237 = load i16, ptr %FillHead, align 2, !dbg !164
  %286 = sext i16 %load_FillHead237 to i32, !dbg !164
  %tmpVar238 = icmp slt i32 %286, 40, !dbg !164
  %287 = zext i1 %tmpVar238 to i8, !dbg !164
  %288 = icmp ne i8 %287, 0, !dbg !164
  br i1 %288, label %condition_body239, label %else235, !dbg !164

continue214:                                      ; preds = %continue236, %continue218
  br label %continue192, !dbg !144

condition_body227:                                ; preds = %condition_body217
  %load_FillHead230 = load i16, ptr %FillHead, align 2, !dbg !165
  %289 = sext i16 %load_FillHead230 to i32, !dbg !165
  %tmpVar231 = icmp sgt i32 %289, 5, !dbg !165
  %290 = zext i1 %tmpVar231 to i8, !dbg !165
  %291 = icmp ne i8 %290, 0, !dbg !165
  br i1 %291, label %condition_body232, label %else228, !dbg !165

continue218:                                      ; preds = %continue229, %condition_body217
  br label %continue214, !dbg !144

condition_body232:                                ; preds = %condition_body227
  %load_FillHead233 = load i16, ptr %FillHead, align 2, !dbg !166
  %292 = sext i16 %load_FillHead233 to i32, !dbg !166
  %tmpVar234 = sub i32 %292, 6, !dbg !166
  %293 = trunc i32 %tmpVar234 to i16, !dbg !166
  store i16 %293, ptr %FillHead, align 2, !dbg !166
  br label %continue229, !dbg !167

else228:                                          ; preds = %condition_body227
  store i16 0, ptr %FillHead, align 2, !dbg !168
  br label %continue229, !dbg !167

continue229:                                      ; preds = %else228, %condition_body232
  br label %continue218, !dbg !169

condition_body239:                                ; preds = %else213
  %load_PVsum241 = load i16, ptr %PVsum, align 2, !dbg !170
  %294 = sext i16 %load_PVsum241 to i32, !dbg !170
  %tmpVar242 = icmp slt i32 %294, 95, !dbg !170
  %295 = zext i1 %tmpVar242 to i8, !dbg !170
  %296 = icmp ne i8 %295, 0, !dbg !170
  %load_PVsum243 = load i16, ptr %PVsum, align 2, !dbg !170
  %297 = sext i16 %load_PVsum243 to i32, !dbg !170
  %tmpVar244 = icmp sgt i32 %297, 125, !dbg !170
  %298 = zext i1 %tmpVar244 to i8, !dbg !170
  %299 = icmp ne i8 %298, 0, !dbg !170
  %300 = or i1 %296, %299, !dbg !170
  %301 = zext i1 %300 to i8, !dbg !170
  %302 = icmp ne i8 %301, 0, !dbg !170
  %load_PipeTemp245 = load i16, ptr %PipeTemp, align 2, !dbg !170
  %303 = sext i16 %load_PipeTemp245 to i32, !dbg !170
  %tmpVar246 = icmp slt i32 %303, 55, !dbg !170
  %304 = zext i1 %tmpVar246 to i8, !dbg !170
  %305 = icmp ne i8 %304, 0, !dbg !170
  %306 = or i1 %302, %305, !dbg !170
  %307 = zext i1 %306 to i8, !dbg !170
  %308 = icmp ne i8 %307, 0, !dbg !170
  %load_PipeTemp247 = load i16, ptr %PipeTemp, align 2, !dbg !170
  %309 = sext i16 %load_PipeTemp247 to i32, !dbg !170
  %tmpVar248 = icmp sgt i32 %309, 70, !dbg !170
  %310 = zext i1 %tmpVar248 to i8, !dbg !170
  %311 = icmp ne i8 %310, 0, !dbg !170
  %312 = or i1 %308, %311, !dbg !170
  %313 = zext i1 %312 to i8, !dbg !170
  %314 = icmp ne i8 %313, 0, !dbg !170
  br i1 %314, label %condition_body249, label %continue240, !dbg !170

else235:                                          ; preds = %else213
  %load_FillHead259 = load i16, ptr %FillHead, align 2, !dbg !171
  %315 = sext i16 %load_FillHead259 to i32, !dbg !171
  %tmpVar260 = icmp slt i32 %315, 48, !dbg !171
  %316 = zext i1 %tmpVar260 to i8, !dbg !171
  %317 = icmp ne i8 %316, 0, !dbg !171
  br i1 %317, label %condition_body261, label %else257, !dbg !171

continue236:                                      ; preds = %continue258, %continue240
  br label %continue214, !dbg !144

condition_body249:                                ; preds = %condition_body239
  %load_FillHead252 = load i16, ptr %FillHead, align 2, !dbg !172
  %318 = sext i16 %load_FillHead252 to i32, !dbg !172
  %tmpVar253 = icmp sgt i32 %318, 5, !dbg !172
  %319 = zext i1 %tmpVar253 to i8, !dbg !172
  %320 = icmp ne i8 %319, 0, !dbg !172
  br i1 %320, label %condition_body254, label %else250, !dbg !172

continue240:                                      ; preds = %continue251, %condition_body239
  br label %continue236, !dbg !144

condition_body254:                                ; preds = %condition_body249
  %load_FillHead255 = load i16, ptr %FillHead, align 2, !dbg !173
  %321 = sext i16 %load_FillHead255 to i32, !dbg !173
  %tmpVar256 = sub i32 %321, 6, !dbg !173
  %322 = trunc i32 %tmpVar256 to i16, !dbg !173
  store i16 %322, ptr %FillHead, align 2, !dbg !173
  br label %continue251, !dbg !174

else250:                                          ; preds = %condition_body249
  store i16 0, ptr %FillHead, align 2, !dbg !175
  br label %continue251, !dbg !174

continue251:                                      ; preds = %else250, %condition_body254
  br label %continue240, !dbg !176

condition_body261:                                ; preds = %else235
  %load_PVsum263 = load i16, ptr %PVsum, align 2, !dbg !177
  %323 = sext i16 %load_PVsum263 to i32, !dbg !177
  %tmpVar264 = icmp slt i32 %323, 65, !dbg !177
  %324 = zext i1 %tmpVar264 to i8, !dbg !177
  %325 = icmp ne i8 %324, 0, !dbg !177
  %load_PVsum265 = load i16, ptr %PVsum, align 2, !dbg !177
  %326 = sext i16 %load_PVsum265 to i32, !dbg !177
  %tmpVar266 = icmp sgt i32 %326, 95, !dbg !177
  %327 = zext i1 %tmpVar266 to i8, !dbg !177
  %328 = icmp ne i8 %327, 0, !dbg !177
  %329 = or i1 %325, %328, !dbg !177
  %330 = zext i1 %329 to i8, !dbg !177
  %331 = icmp ne i8 %330, 0, !dbg !177
  %load_PipeTemp267 = load i16, ptr %PipeTemp, align 2, !dbg !177
  %332 = sext i16 %load_PipeTemp267 to i32, !dbg !177
  %tmpVar268 = icmp slt i32 %332, 78, !dbg !177
  %333 = zext i1 %tmpVar268 to i8, !dbg !177
  %334 = icmp ne i8 %333, 0, !dbg !177
  %335 = or i1 %331, %334, !dbg !177
  %336 = zext i1 %335 to i8, !dbg !177
  %337 = icmp ne i8 %336, 0, !dbg !177
  %load_PipeTemp269 = load i16, ptr %PipeTemp, align 2, !dbg !177
  %338 = sext i16 %load_PipeTemp269 to i32, !dbg !177
  %tmpVar270 = icmp sgt i32 %338, 93, !dbg !177
  %339 = zext i1 %tmpVar270 to i8, !dbg !177
  %340 = icmp ne i8 %339, 0, !dbg !177
  %341 = or i1 %337, %340, !dbg !177
  %342 = zext i1 %341 to i8, !dbg !177
  %343 = icmp ne i8 %342, 0, !dbg !177
  br i1 %343, label %condition_body271, label %continue262, !dbg !177

else257:                                          ; preds = %else235
  %load_FillHead281 = load i16, ptr %FillHead, align 2, !dbg !178
  %344 = sext i16 %load_FillHead281 to i32, !dbg !178
  %tmpVar282 = icmp slt i32 %344, 56, !dbg !178
  %345 = zext i1 %tmpVar282 to i8, !dbg !178
  %346 = icmp ne i8 %345, 0, !dbg !178
  br i1 %346, label %condition_body283, label %else279, !dbg !178

continue258:                                      ; preds = %continue280, %continue262
  br label %continue236, !dbg !144

condition_body271:                                ; preds = %condition_body261
  %load_FillHead274 = load i16, ptr %FillHead, align 2, !dbg !179
  %347 = sext i16 %load_FillHead274 to i32, !dbg !179
  %tmpVar275 = icmp sgt i32 %347, 5, !dbg !179
  %348 = zext i1 %tmpVar275 to i8, !dbg !179
  %349 = icmp ne i8 %348, 0, !dbg !179
  br i1 %349, label %condition_body276, label %else272, !dbg !179

continue262:                                      ; preds = %continue273, %condition_body261
  br label %continue258, !dbg !144

condition_body276:                                ; preds = %condition_body271
  %load_FillHead277 = load i16, ptr %FillHead, align 2, !dbg !180
  %350 = sext i16 %load_FillHead277 to i32, !dbg !180
  %tmpVar278 = sub i32 %350, 6, !dbg !180
  %351 = trunc i32 %tmpVar278 to i16, !dbg !180
  store i16 %351, ptr %FillHead, align 2, !dbg !180
  br label %continue273, !dbg !181

else272:                                          ; preds = %condition_body271
  store i16 0, ptr %FillHead, align 2, !dbg !182
  br label %continue273, !dbg !181

continue273:                                      ; preds = %else272, %condition_body276
  br label %continue262, !dbg !183

condition_body283:                                ; preds = %else257
  %load_PVsum285 = load i16, ptr %PVsum, align 2, !dbg !184
  %352 = sext i16 %load_PVsum285 to i32, !dbg !184
  %tmpVar286 = icmp slt i32 %352, 85, !dbg !184
  %353 = zext i1 %tmpVar286 to i8, !dbg !184
  %354 = icmp ne i8 %353, 0, !dbg !184
  %load_PVsum287 = load i16, ptr %PVsum, align 2, !dbg !184
  %355 = sext i16 %load_PVsum287 to i32, !dbg !184
  %tmpVar288 = icmp sgt i32 %355, 115, !dbg !184
  %356 = zext i1 %tmpVar288 to i8, !dbg !184
  %357 = icmp ne i8 %356, 0, !dbg !184
  %358 = or i1 %354, %357, !dbg !184
  %359 = zext i1 %358 to i8, !dbg !184
  %360 = icmp ne i8 %359, 0, !dbg !184
  %load_PipeTemp289 = load i16, ptr %PipeTemp, align 2, !dbg !184
  %361 = sext i16 %load_PipeTemp289 to i32, !dbg !184
  %tmpVar290 = icmp slt i32 %361, 52, !dbg !184
  %362 = zext i1 %tmpVar290 to i8, !dbg !184
  %363 = icmp ne i8 %362, 0, !dbg !184
  %364 = or i1 %360, %363, !dbg !184
  %365 = zext i1 %364 to i8, !dbg !184
  %366 = icmp ne i8 %365, 0, !dbg !184
  %load_PipeTemp291 = load i16, ptr %PipeTemp, align 2, !dbg !184
  %367 = sext i16 %load_PipeTemp291 to i32, !dbg !184
  %tmpVar292 = icmp sgt i32 %367, 67, !dbg !184
  %368 = zext i1 %tmpVar292 to i8, !dbg !184
  %369 = icmp ne i8 %368, 0, !dbg !184
  %370 = or i1 %366, %369, !dbg !184
  %371 = zext i1 %370 to i8, !dbg !184
  %372 = icmp ne i8 %371, 0, !dbg !184
  br i1 %372, label %condition_body293, label %continue284, !dbg !184

else279:                                          ; preds = %else257
  %load_PVsum302 = load i16, ptr %PVsum, align 2, !dbg !185
  %373 = sext i16 %load_PVsum302 to i32, !dbg !185
  %tmpVar303 = icmp slt i32 %373, 75, !dbg !185
  %374 = zext i1 %tmpVar303 to i8, !dbg !185
  %375 = icmp ne i8 %374, 0, !dbg !185
  %load_PVsum304 = load i16, ptr %PVsum, align 2, !dbg !185
  %376 = sext i16 %load_PVsum304 to i32, !dbg !185
  %tmpVar305 = icmp sgt i32 %376, 105, !dbg !185
  %377 = zext i1 %tmpVar305 to i8, !dbg !185
  %378 = icmp ne i8 %377, 0, !dbg !185
  %379 = or i1 %375, %378, !dbg !185
  %380 = zext i1 %379 to i8, !dbg !185
  %381 = icmp ne i8 %380, 0, !dbg !185
  %load_PipeTemp306 = load i16, ptr %PipeTemp, align 2, !dbg !185
  %382 = sext i16 %load_PipeTemp306 to i32, !dbg !185
  %tmpVar307 = icmp slt i32 %382, 63, !dbg !185
  %383 = zext i1 %tmpVar307 to i8, !dbg !185
  %384 = icmp ne i8 %383, 0, !dbg !185
  %385 = or i1 %381, %384, !dbg !185
  %386 = zext i1 %385 to i8, !dbg !185
  %387 = icmp ne i8 %386, 0, !dbg !185
  %load_PipeTemp308 = load i16, ptr %PipeTemp, align 2, !dbg !185
  %388 = sext i16 %load_PipeTemp308 to i32, !dbg !185
  %tmpVar309 = icmp sgt i32 %388, 78, !dbg !185
  %389 = zext i1 %tmpVar309 to i8, !dbg !185
  %390 = icmp ne i8 %389, 0, !dbg !185
  %391 = or i1 %387, %390, !dbg !185
  %392 = zext i1 %391 to i8, !dbg !185
  %393 = icmp ne i8 %392, 0, !dbg !185
  br i1 %393, label %condition_body310, label %continue301, !dbg !185

continue280:                                      ; preds = %continue301, %continue284
  br label %continue258, !dbg !144

condition_body293:                                ; preds = %condition_body283
  %load_FillHead296 = load i16, ptr %FillHead, align 2, !dbg !186
  %394 = sext i16 %load_FillHead296 to i32, !dbg !186
  %tmpVar297 = icmp sgt i32 %394, 5, !dbg !186
  %395 = zext i1 %tmpVar297 to i8, !dbg !186
  %396 = icmp ne i8 %395, 0, !dbg !186
  br i1 %396, label %condition_body298, label %else294, !dbg !186

continue284:                                      ; preds = %continue295, %condition_body283
  br label %continue280, !dbg !144

condition_body298:                                ; preds = %condition_body293
  %load_FillHead299 = load i16, ptr %FillHead, align 2, !dbg !187
  %397 = sext i16 %load_FillHead299 to i32, !dbg !187
  %tmpVar300 = sub i32 %397, 6, !dbg !187
  %398 = trunc i32 %tmpVar300 to i16, !dbg !187
  store i16 %398, ptr %FillHead, align 2, !dbg !187
  br label %continue295, !dbg !188

else294:                                          ; preds = %condition_body293
  store i16 0, ptr %FillHead, align 2, !dbg !189
  br label %continue295, !dbg !188

continue295:                                      ; preds = %else294, %condition_body298
  br label %continue284, !dbg !190

condition_body310:                                ; preds = %else279
  %load_FillHead313 = load i16, ptr %FillHead, align 2, !dbg !191
  %399 = sext i16 %load_FillHead313 to i32, !dbg !191
  %tmpVar314 = icmp sgt i32 %399, 5, !dbg !191
  %400 = zext i1 %tmpVar314 to i8, !dbg !191
  %401 = icmp ne i8 %400, 0, !dbg !191
  br i1 %401, label %condition_body315, label %else311, !dbg !191

continue301:                                      ; preds = %continue312, %else279
  br label %continue280, !dbg !144

condition_body315:                                ; preds = %condition_body310
  %load_FillHead316 = load i16, ptr %FillHead, align 2, !dbg !192
  %402 = sext i16 %load_FillHead316 to i32, !dbg !192
  %tmpVar317 = sub i32 %402, 6, !dbg !192
  %403 = trunc i32 %tmpVar317 to i16, !dbg !192
  store i16 %403, ptr %FillHead, align 2, !dbg !192
  br label %continue312, !dbg !193

else311:                                          ; preds = %condition_body310
  store i16 0, ptr %FillHead, align 2, !dbg !194
  br label %continue312, !dbg !193

continue312:                                      ; preds = %else311, %condition_body315
  br label %continue301, !dbg !195
}

define void @PLC_PRG(ptr %0) !dbg !196 {
entry:
    #dbg_declare(ptr %0, !199, !DIExpression(), !200)
  %PumpRate = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 0
  %ValvePos = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 1
  %PipeTemp = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 2
  %BackPressure = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 3
  %FeedConc = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 4
  %CoolantRate = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 5
  %Cmd = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 6
  %Ctrl = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 7
  %1 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 1, !dbg !200
  %load_PumpRate = load i16, ptr %PumpRate, align 2, !dbg !200
  store i16 %load_PumpRate, ptr %1, align 2, !dbg !200
  %2 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 2, !dbg !200
  %load_ValvePos = load i16, ptr %ValvePos, align 2, !dbg !200
  store i16 %load_ValvePos, ptr %2, align 2, !dbg !200
  %3 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 3, !dbg !200
  %load_PipeTemp = load i16, ptr %PipeTemp, align 2, !dbg !200
  store i16 %load_PipeTemp, ptr %3, align 2, !dbg !200
  %4 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 4, !dbg !200
  %load_BackPressure = load i16, ptr %BackPressure, align 2, !dbg !200
  store i16 %load_BackPressure, ptr %4, align 2, !dbg !200
  %5 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 5, !dbg !200
  %load_FeedConc = load i16, ptr %FeedConc, align 2, !dbg !200
  store i16 %load_FeedConc, ptr %5, align 2, !dbg !200
  %6 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 6, !dbg !200
  %load_CoolantRate = load i16, ptr %CoolantRate, align 2, !dbg !200
  store i16 %load_CoolantRate, ptr %6, align 2, !dbg !200
  %7 = getelementptr inbounds %PipelineCtrl, ptr %Ctrl, i32 0, i32 7, !dbg !200
  %load_Cmd = load i8, ptr %Cmd, align 1, !dbg !200
  store i8 %load_Cmd, ptr %7, align 1, !dbg !200
  call void @PipelineCtrl(ptr %Ctrl), !dbg !200
  ret void, !dbg !201
}

define void @PLC_PRG__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !76
  store ptr %0, ptr %self, align 8, !dbg !76
  %deref = load ptr, ptr %self, align 8, !dbg !76
  %PumpRate = getelementptr inbounds nuw %PLC_PRG, ptr %deref, i32 0, i32 0, !dbg !76
  store i16 0, ptr %PumpRate, align 2, !dbg !76
  %deref1 = load ptr, ptr %self, align 8, !dbg !76
  %ValvePos = getelementptr inbounds nuw %PLC_PRG, ptr %deref1, i32 0, i32 1, !dbg !76
  store i16 0, ptr %ValvePos, align 2, !dbg !76
  %deref2 = load ptr, ptr %self, align 8, !dbg !76
  %PipeTemp = getelementptr inbounds nuw %PLC_PRG, ptr %deref2, i32 0, i32 2, !dbg !76
  store i16 0, ptr %PipeTemp, align 2, !dbg !76
  %deref3 = load ptr, ptr %self, align 8, !dbg !76
  %BackPressure = getelementptr inbounds nuw %PLC_PRG, ptr %deref3, i32 0, i32 3, !dbg !76
  store i16 0, ptr %BackPressure, align 2, !dbg !76
  %deref4 = load ptr, ptr %self, align 8, !dbg !76
  %FeedConc = getelementptr inbounds nuw %PLC_PRG, ptr %deref4, i32 0, i32 4, !dbg !76
  store i16 0, ptr %FeedConc, align 2, !dbg !76
  %deref5 = load ptr, ptr %self, align 8, !dbg !76
  %CoolantRate = getelementptr inbounds nuw %PLC_PRG, ptr %deref5, i32 0, i32 5, !dbg !76
  store i16 0, ptr %CoolantRate, align 2, !dbg !76
  %deref6 = load ptr, ptr %self, align 8, !dbg !76
  %Cmd = getelementptr inbounds nuw %PLC_PRG, ptr %deref6, i32 0, i32 6, !dbg !76
  store i8 0, ptr %Cmd, align 1, !dbg !76
  %deref7 = load ptr, ptr %self, align 8, !dbg !76
  %Ctrl = getelementptr inbounds nuw %PLC_PRG, ptr %deref7, i32 0, i32 7, !dbg !76
  call void @PipelineCtrl__ctor(ptr %Ctrl), !dbg !76
  ret void, !dbg !76
}

define void @PipelineCtrl__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !76
  store ptr %0, ptr %self, align 8, !dbg !76
  %deref = load ptr, ptr %self, align 8, !dbg !76
  %__vtable = getelementptr inbounds nuw %PipelineCtrl, ptr %deref, i32 0, i32 0, !dbg !76
  call void @__PipelineCtrl___vtable__ctor(ptr %__vtable), !dbg !76
  %deref1 = load ptr, ptr %self, align 8, !dbg !76
  %Phase = getelementptr inbounds nuw %PipelineCtrl, ptr %deref1, i32 0, i32 9, !dbg !76
  store i8 0, ptr %Phase, align 1, !dbg !76
  %deref2 = load ptr, ptr %self, align 8, !dbg !76
  %CycleCount = getelementptr inbounds nuw %PipelineCtrl, ptr %deref2, i32 0, i32 10, !dbg !76
  store i16 0, ptr %CycleCount, align 2, !dbg !76
  %deref3 = load ptr, ptr %self, align 8, !dbg !76
  %PrimeCycles = getelementptr inbounds nuw %PipelineCtrl, ptr %deref3, i32 0, i32 11, !dbg !76
  store i16 0, ptr %PrimeCycles, align 2, !dbg !76
  %deref4 = load ptr, ptr %self, align 8, !dbg !76
  %PrimeScore = getelementptr inbounds nuw %PipelineCtrl, ptr %deref4, i32 0, i32 12, !dbg !76
  store i16 0, ptr %PrimeScore, align 2, !dbg !76
  %deref5 = load ptr, ptr %self, align 8, !dbg !76
  %FluxScore = getelementptr inbounds nuw %PipelineCtrl, ptr %deref5, i32 0, i32 13, !dbg !76
  store i16 0, ptr %FluxScore, align 2, !dbg !76
  %deref6 = load ptr, ptr %self, align 8, !dbg !76
  %FluxSum = getelementptr inbounds nuw %PipelineCtrl, ptr %deref6, i32 0, i32 14, !dbg !76
  store i16 0, ptr %FluxSum, align 2, !dbg !76
  %deref7 = load ptr, ptr %self, align 8, !dbg !76
  %FlowAccum = getelementptr inbounds nuw %PipelineCtrl, ptr %deref7, i32 0, i32 15, !dbg !76
  store i16 0, ptr %FlowAccum, align 2, !dbg !76
  %deref8 = load ptr, ptr %self, align 8, !dbg !76
  %PressAccum = getelementptr inbounds nuw %PipelineCtrl, ptr %deref8, i32 0, i32 16, !dbg !76
  store i16 0, ptr %PressAccum, align 2, !dbg !76
  %deref9 = load ptr, ptr %self, align 8, !dbg !76
  %TempAccum = getelementptr inbounds nuw %PipelineCtrl, ptr %deref9, i32 0, i32 17, !dbg !76
  store i16 0, ptr %TempAccum, align 2, !dbg !76
  %deref10 = load ptr, ptr %self, align 8, !dbg !76
  %PhaseCounter = getelementptr inbounds nuw %PipelineCtrl, ptr %deref10, i32 0, i32 18, !dbg !76
  store i16 0, ptr %PhaseCounter, align 2, !dbg !76
  %deref11 = load ptr, ptr %self, align 8, !dbg !76
  %FillHead = getelementptr inbounds nuw %PipelineCtrl, ptr %deref11, i32 0, i32 19, !dbg !76
  store i16 0, ptr %FillHead, align 2, !dbg !76
  %deref12 = load ptr, ptr %self, align 8, !dbg !76
  %Buffer = getelementptr inbounds nuw %PipelineCtrl, ptr %deref12, i32 0, i32 20, !dbg !76
  call void @__PipelineCtrl_Buffer__ctor(ptr %Buffer), !dbg !76
  %deref13 = load ptr, ptr %self, align 8, !dbg !76
  %PVsum = getelementptr inbounds nuw %PipelineCtrl, ptr %deref13, i32 0, i32 21, !dbg !76
  store i16 0, ptr %PVsum, align 2, !dbg !76
  %deref14 = load ptr, ptr %self, align 8, !dbg !76
  %__vtable15 = getelementptr inbounds nuw %PipelineCtrl, ptr %deref14, i32 0, i32 0, !dbg !76
  store ptr @__vtable_PipelineCtrl_instance, ptr %__vtable15, align 8, !dbg !76
  ret void, !dbg !76
}

define void @__PipelineCtrl_Buffer__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !76
  store ptr %0, ptr %self, align 8, !dbg !76
  ret void, !dbg !76
}

define void @__vtable_PipelineCtrl__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !76
  store ptr %0, ptr %self, align 8, !dbg !76
  %deref = load ptr, ptr %self, align 8, !dbg !76
  %__body = getelementptr inbounds nuw %__vtable_PipelineCtrl, ptr %deref, i32 0, i32 0, !dbg !76
  call void @____vtable_PipelineCtrl___body__ctor(ptr %__body), !dbg !76
  %deref1 = load ptr, ptr %self, align 8, !dbg !76
  %__body2 = getelementptr inbounds nuw %__vtable_PipelineCtrl, ptr %deref1, i32 0, i32 0, !dbg !76
  store ptr @PipelineCtrl, ptr %__body2, align 8, !dbg !76
  ret void, !dbg !76
}

define void @__PipelineCtrl___vtable__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !76
  store ptr %0, ptr %self, align 8, !dbg !76
  ret void, !dbg !76
}

define void @____vtable_PipelineCtrl___body__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !76
  store ptr %0, ptr %self, align 8, !dbg !76
  ret void, !dbg !76
}

define void @__unit_pipeline_controller_st__ctor() {
entry:
  call void @__vtable_PipelineCtrl__ctor(ptr @__vtable_PipelineCtrl_instance), !dbg !76
  call void @PLC_PRG__ctor(ptr @PLC_PRG_instance), !dbg !76
  ret void, !dbg !76
}

!llvm.module.flags = !{!55, !56}
!llvm.dbg.cu = !{!57}

!0 = !DIGlobalVariableExpression(var: !1, expr: !DIExpression())
!1 = distinct !DIGlobalVariable(name: "PHASE_IDLE", scope: !2, file: !2, line: 57, type: !3, isLocal: false, isDefinition: true)
!2 = !DIFile(filename: "benchmarks/pipeline_controller.st", directory: "/workspaces/ICSPrism")
!3 = !DIDerivedType(tag: DW_TAG_const_type, baseType: !4)
!4 = !DIBasicType(name: "SINT", size: 8, encoding: DW_ATE_signed, flags: DIFlagPublic)
!5 = !DIGlobalVariableExpression(var: !6, expr: !DIExpression())
!6 = distinct !DIGlobalVariable(name: "PHASE_PRIME", scope: !2, file: !2, line: 58, type: !3, isLocal: false, isDefinition: true)
!7 = !DIGlobalVariableExpression(var: !8, expr: !DIExpression())
!8 = distinct !DIGlobalVariable(name: "PHASE_FLOW", scope: !2, file: !2, line: 59, type: !3, isLocal: false, isDefinition: true)
!9 = !DIGlobalVariableExpression(var: !10, expr: !DIExpression())
!10 = distinct !DIGlobalVariable(name: "PHASE_FILL", scope: !2, file: !2, line: 60, type: !3, isLocal: false, isDefinition: true)
!11 = !DIGlobalVariableExpression(var: !12, expr: !DIExpression())
!12 = distinct !DIGlobalVariable(name: "PLC_PRG", scope: !2, file: !2, line: 63, type: !13, isLocal: false, isDefinition: true)
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
!25 = !{!26, !30, !31, !32, !33, !34, !35, !36, !37, !38, !39, !40, !41, !42, !43, !44, !45, !46, !47, !48, !49, !53, !54}
!26 = !DIDerivedType(tag: DW_TAG_member, name: "__vtable", scope: !2, file: !2, baseType: !27, size: 64, align: 64, flags: DIFlagPublic)
!27 = !DIDerivedType(tag: DW_TAG_typedef, name: "__POINTER_TO____PipelineCtrl___vtable", scope: !2, file: !2, baseType: !28, align: 64)
!28 = !DIDerivedType(tag: DW_TAG_pointer_type, name: "__PipelineCtrl___vtable", baseType: !29, size: 64, align: 64, dwarfAddressSpace: 1)
!29 = !DIBasicType(name: "__VOID", encoding: DW_ATE_unsigned, flags: DIFlagPublic)
!30 = !DIDerivedType(tag: DW_TAG_member, name: "PumpRate", scope: !2, file: !2, line: 92, baseType: !16, size: 16, align: 16, offset: 64, flags: DIFlagPublic)
!31 = !DIDerivedType(tag: DW_TAG_member, name: "ValvePos", scope: !2, file: !2, line: 93, baseType: !16, size: 16, align: 16, offset: 80, flags: DIFlagPublic)
!32 = !DIDerivedType(tag: DW_TAG_member, name: "PipeTemp", scope: !2, file: !2, line: 94, baseType: !16, size: 16, align: 16, offset: 96, flags: DIFlagPublic)
!33 = !DIDerivedType(tag: DW_TAG_member, name: "BackPressure", scope: !2, file: !2, line: 95, baseType: !16, size: 16, align: 16, offset: 112, flags: DIFlagPublic)
!34 = !DIDerivedType(tag: DW_TAG_member, name: "FeedConc", scope: !2, file: !2, line: 96, baseType: !16, size: 16, align: 16, offset: 128, flags: DIFlagPublic)
!35 = !DIDerivedType(tag: DW_TAG_member, name: "CoolantRate", scope: !2, file: !2, line: 97, baseType: !16, size: 16, align: 16, offset: 144, flags: DIFlagPublic)
!36 = !DIDerivedType(tag: DW_TAG_member, name: "Cmd", scope: !2, file: !2, line: 98, baseType: !4, size: 8, align: 8, offset: 160, flags: DIFlagPublic)
!37 = !DIDerivedType(tag: DW_TAG_member, name: "Status", scope: !2, file: !2, line: 101, baseType: !4, size: 8, align: 8, offset: 168, flags: DIFlagPublic)
!38 = !DIDerivedType(tag: DW_TAG_member, name: "Phase", scope: !2, file: !2, line: 104, baseType: !4, size: 8, align: 8, offset: 176, flags: DIFlagPublic)
!39 = !DIDerivedType(tag: DW_TAG_member, name: "CycleCount", scope: !2, file: !2, line: 105, baseType: !16, size: 16, align: 16, offset: 192, flags: DIFlagPublic)
!40 = !DIDerivedType(tag: DW_TAG_member, name: "PrimeCycles", scope: !2, file: !2, line: 107, baseType: !16, size: 16, align: 16, offset: 208, flags: DIFlagPublic)
!41 = !DIDerivedType(tag: DW_TAG_member, name: "PrimeScore", scope: !2, file: !2, line: 108, baseType: !16, size: 16, align: 16, offset: 224, flags: DIFlagPublic)
!42 = !DIDerivedType(tag: DW_TAG_member, name: "FluxScore", scope: !2, file: !2, line: 110, baseType: !16, size: 16, align: 16, offset: 240, flags: DIFlagPublic)
!43 = !DIDerivedType(tag: DW_TAG_member, name: "FluxSum", scope: !2, file: !2, line: 111, baseType: !16, size: 16, align: 16, offset: 256, flags: DIFlagPublic)
!44 = !DIDerivedType(tag: DW_TAG_member, name: "FlowAccum", scope: !2, file: !2, line: 113, baseType: !16, size: 16, align: 16, offset: 272, flags: DIFlagPublic)
!45 = !DIDerivedType(tag: DW_TAG_member, name: "PressAccum", scope: !2, file: !2, line: 114, baseType: !16, size: 16, align: 16, offset: 288, flags: DIFlagPublic)
!46 = !DIDerivedType(tag: DW_TAG_member, name: "TempAccum", scope: !2, file: !2, line: 115, baseType: !16, size: 16, align: 16, offset: 304, flags: DIFlagPublic)
!47 = !DIDerivedType(tag: DW_TAG_member, name: "PhaseCounter", scope: !2, file: !2, line: 116, baseType: !16, size: 16, align: 16, offset: 320, flags: DIFlagPublic)
!48 = !DIDerivedType(tag: DW_TAG_member, name: "FillHead", scope: !2, file: !2, line: 118, baseType: !16, size: 16, align: 16, offset: 336, flags: DIFlagPublic)
!49 = !DIDerivedType(tag: DW_TAG_member, name: "Buffer", scope: !2, file: !2, line: 120, baseType: !50, size: 1024, align: 16, offset: 352, flags: DIFlagPublic)
!50 = !DICompositeType(tag: DW_TAG_array_type, baseType: !16, size: 1024, align: 16, elements: !51)
!51 = !{!52}
!52 = !DISubrange(count: 64, lowerBound: 0)
!53 = !DIDerivedType(tag: DW_TAG_member, name: "PVsum", scope: !2, file: !2, line: 121, baseType: !16, size: 16, align: 16, offset: 1376, flags: DIFlagPublic)
!54 = !DIDerivedType(tag: DW_TAG_member, name: "i", scope: !2, file: !2, line: 122, baseType: !16, size: 16, align: 16, offset: 1392, flags: DIFlagPublic)
!55 = !{i32 2, !"Dwarf Version", i32 5}
!56 = !{i32 2, !"Debug Info Version", i32 3}
!57 = distinct !DICompileUnit(language: DW_LANG_C, file: !2, producer: "RuSTy Structured text Compiler", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, globals: !58, splitDebugInlining: false)
!58 = !{!0, !5, !7, !9, !11}
!59 = distinct !DISubprogram(name: "PipelineCtrl", linkageName: "PipelineCtrl", scope: !2, file: !2, line: 90, type: !60, scopeLine: 125, flags: DIFlagPublic, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !57, retainedNodes: !62)
!60 = !DISubroutineType(flags: DIFlagPublic, types: !61)
!61 = !{null, !24, !16, !16, !16, !16, !16, !16, !4, !4}
!62 = !{}
!63 = !DILocalVariable(name: "PipelineCtrl", scope: !59, file: !2, line: 125, type: !24)
!64 = !DILocation(line: 125, scope: !59)
!65 = !DILocation(line: 127, column: 5, scope: !59)
!66 = !DILocation(line: 130, column: 11, scope: !59)
!67 = !DILocation(line: 150, column: 8, scope: !59)
!68 = !DILocation(line: 151, column: 8, scope: !59)
!69 = !DILocation(line: 153, column: 11, scope: !59)
!70 = !DILocation(line: 172, column: 8, scope: !59)
!71 = !DILocation(line: 174, column: 11, scope: !59)
!72 = !DILocation(line: 193, column: 8, scope: !59)
!73 = !DILocation(line: 198, column: 11, scope: !59)
!74 = !DILocation(line: 341, scope: !59)
!75 = !DILocation(line: 343, scope: !59)
!76 = !DILocation(line: 345, scope: !59)
!77 = !DILocation(line: 131, column: 16, scope: !59)
!78 = !DILocation(line: 0, scope: !59)
!79 = !DILocation(line: 134, column: 12, scope: !59)
!80 = !DILocation(line: 135, column: 12, scope: !59)
!81 = !DILocation(line: 136, column: 12, scope: !59)
!82 = !DILocation(line: 137, column: 12, scope: !59)
!83 = !DILocation(line: 138, column: 12, scope: !59)
!84 = !DILocation(line: 139, column: 12, scope: !59)
!85 = !DILocation(line: 140, column: 12, scope: !59)
!86 = !DILocation(line: 141, column: 12, scope: !59)
!87 = !DILocation(line: 142, column: 12, scope: !59)
!88 = !DILocation(line: 143, column: 12, scope: !59)
!89 = !DILocation(line: 144, column: 8, scope: !59)
!90 = !DILocation(line: 132, column: 16, scope: !59)
!91 = !DILocation(line: 154, column: 15, scope: !59)
!92 = !DILocation(line: 165, column: 11, scope: !59)
!93 = !DILocation(line: 155, column: 16, scope: !59)
!94 = !DILocation(line: 162, column: 12, scope: !59)
!95 = !DILocation(line: 157, column: 19, scope: !59)
!96 = !DILocation(line: 163, column: 8, scope: !59)
!97 = !DILocation(line: 158, column: 20, scope: !59)
!98 = !DILocation(line: 161, column: 16, scope: !59)
!99 = !DILocation(line: 160, column: 20, scope: !59)
!100 = !DILocation(line: 166, column: 12, scope: !59)
!101 = !DILocation(line: 167, column: 8, scope: !59)
!102 = !DILocation(line: 175, column: 12, scope: !59)
!103 = !DILocation(line: 182, column: 8, scope: !59)
!104 = !DILocation(line: 177, column: 15, scope: !59)
!105 = !DILocation(line: 184, column: 11, scope: !59)
!106 = !DILocation(line: 178, column: 16, scope: !59)
!107 = !DILocation(line: 181, column: 12, scope: !59)
!108 = !DILocation(line: 180, column: 16, scope: !59)
!109 = !DILocation(line: 185, column: 12, scope: !59)
!110 = !DILocation(line: 186, column: 8, scope: !59)
!111 = !DILocation(line: 188, column: 11, scope: !59)
!112 = !DILocation(line: 189, column: 12, scope: !59)
!113 = !DILocation(line: 190, column: 8, scope: !59)
!114 = !DILocation(line: 199, column: 12, scope: !59)
!115 = !DILocation(line: 206, column: 8, scope: !59)
!116 = !DILocation(line: 201, column: 15, scope: !59)
!117 = !DILocation(line: 208, column: 11, scope: !59)
!118 = !DILocation(line: 202, column: 16, scope: !59)
!119 = !DILocation(line: 205, column: 12, scope: !59)
!120 = !DILocation(line: 204, column: 16, scope: !59)
!121 = !DILocation(line: 209, column: 12, scope: !59)
!122 = !DILocation(line: 214, column: 8, scope: !59)
!123 = !DILocation(line: 211, column: 15, scope: !59)
!124 = !DILocation(line: 218, column: 11, scope: !59)
!125 = !DILocation(line: 212, column: 16, scope: !59)
!126 = !DILocation(line: 213, column: 12, scope: !59)
!127 = !DILocation(line: 219, column: 12, scope: !59)
!128 = !DILocation(line: 226, column: 8, scope: !59)
!129 = !DILocation(line: 221, column: 15, scope: !59)
!130 = !DILocation(line: 230, column: 11, scope: !59)
!131 = !DILocation(line: 222, column: 16, scope: !59)
!132 = !DILocation(line: 225, column: 12, scope: !59)
!133 = !DILocation(line: 224, column: 16, scope: !59)
!134 = !DILocation(line: 231, column: 15, scope: !59)
!135 = !DILocation(line: 257, column: 8, scope: !59)
!136 = !DILocation(line: 259, column: 11, scope: !59)
!137 = !DILocation(line: 232, column: 16, scope: !59)
!138 = !DILocation(line: 233, column: 12, scope: !59)
!139 = !DILocation(line: 234, column: 8, scope: !59)
!140 = !DILocation(line: 261, column: 15, scope: !59)
!141 = !DILocation(line: 268, column: 14, scope: !59)
!142 = !DILocation(line: 339, column: 8, scope: !59)
!143 = !DILocation(line: 262, column: 19, scope: !59)
!144 = !DILocation(line: 334, column: 8, scope: !59)
!145 = !DILocation(line: 263, column: 20, scope: !59)
!146 = !DILocation(line: 266, column: 16, scope: !59)
!147 = !DILocation(line: 265, column: 20, scope: !59)
!148 = !DILocation(line: 267, column: 12, scope: !59)
!149 = !DILocation(line: 270, column: 15, scope: !59)
!150 = !DILocation(line: 277, column: 14, scope: !59)
!151 = !DILocation(line: 271, column: 19, scope: !59)
!152 = !DILocation(line: 272, column: 20, scope: !59)
!153 = !DILocation(line: 275, column: 16, scope: !59)
!154 = !DILocation(line: 274, column: 20, scope: !59)
!155 = !DILocation(line: 276, column: 12, scope: !59)
!156 = !DILocation(line: 279, column: 15, scope: !59)
!157 = !DILocation(line: 286, column: 14, scope: !59)
!158 = !DILocation(line: 280, column: 19, scope: !59)
!159 = !DILocation(line: 281, column: 20, scope: !59)
!160 = !DILocation(line: 284, column: 16, scope: !59)
!161 = !DILocation(line: 283, column: 20, scope: !59)
!162 = !DILocation(line: 285, column: 12, scope: !59)
!163 = !DILocation(line: 288, column: 15, scope: !59)
!164 = !DILocation(line: 295, column: 14, scope: !59)
!165 = !DILocation(line: 289, column: 19, scope: !59)
!166 = !DILocation(line: 290, column: 20, scope: !59)
!167 = !DILocation(line: 293, column: 16, scope: !59)
!168 = !DILocation(line: 292, column: 20, scope: !59)
!169 = !DILocation(line: 294, column: 12, scope: !59)
!170 = !DILocation(line: 298, column: 15, scope: !59)
!171 = !DILocation(line: 305, column: 14, scope: !59)
!172 = !DILocation(line: 299, column: 19, scope: !59)
!173 = !DILocation(line: 300, column: 20, scope: !59)
!174 = !DILocation(line: 303, column: 16, scope: !59)
!175 = !DILocation(line: 302, column: 20, scope: !59)
!176 = !DILocation(line: 304, column: 12, scope: !59)
!177 = !DILocation(line: 308, column: 15, scope: !59)
!178 = !DILocation(line: 315, column: 14, scope: !59)
!179 = !DILocation(line: 309, column: 19, scope: !59)
!180 = !DILocation(line: 310, column: 20, scope: !59)
!181 = !DILocation(line: 313, column: 16, scope: !59)
!182 = !DILocation(line: 312, column: 20, scope: !59)
!183 = !DILocation(line: 314, column: 12, scope: !59)
!184 = !DILocation(line: 318, column: 15, scope: !59)
!185 = !DILocation(line: 327, column: 15, scope: !59)
!186 = !DILocation(line: 319, column: 19, scope: !59)
!187 = !DILocation(line: 320, column: 20, scope: !59)
!188 = !DILocation(line: 323, column: 16, scope: !59)
!189 = !DILocation(line: 322, column: 20, scope: !59)
!190 = !DILocation(line: 324, column: 12, scope: !59)
!191 = !DILocation(line: 328, column: 19, scope: !59)
!192 = !DILocation(line: 329, column: 20, scope: !59)
!193 = !DILocation(line: 332, column: 16, scope: !59)
!194 = !DILocation(line: 331, column: 20, scope: !59)
!195 = !DILocation(line: 333, column: 12, scope: !59)
!196 = distinct !DISubprogram(name: "PLC_PRG", linkageName: "PLC_PRG", scope: !2, file: !2, line: 63, type: !197, scopeLine: 77, flags: DIFlagPublic, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !57, retainedNodes: !62)
!197 = !DISubroutineType(flags: DIFlagPublic, types: !198)
!198 = !{null, !13, !16, !16, !16, !16, !16, !16, !4}
!199 = !DILocalVariable(name: "PLC_PRG", scope: !196, file: !2, line: 77, type: !13)
!200 = !DILocation(line: 77, scope: !196)
!201 = !DILocation(line: 87, scope: !196)
