; ModuleID = '/tmp/.tmpTJtPuQ/benchmarks/harness_test.st.ll'
source_filename = "/workspaces/ICSPrism/benchmarks/harness_test.st"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%__vtable_Counter = type { ptr }
%HarnessTest = type { i16, i16, i8, i16, i16, i32, [16 x i16], %Counter, i16 }
%Counter = type { ptr, i16, i8, i16, i16 }

@__vtable_Counter_instance = global %__vtable_Counter zeroinitializer
@HarnessTest_instance = global %HarnessTest zeroinitializer, !dbg !0
@llvm.global_ctors = appending global [1 x { i32, ptr, ptr }] [{ i32, ptr, ptr } { i32 65535, ptr @__unit_harness_test_st__ctor, ptr null }]

define void @Counter(ptr %0) !dbg !34 {
entry:
    #dbg_declare(ptr %0, !38, !DIExpression(), !39)
  %this = alloca ptr, align 8
  store ptr %0, ptr %this, align 8
  %__vtable = getelementptr inbounds nuw %Counter, ptr %0, i32 0, i32 0
  %Increment = getelementptr inbounds nuw %Counter, ptr %0, i32 0, i32 1
  %Reset = getelementptr inbounds nuw %Counter, ptr %0, i32 0, i32 2
  %Value = getelementptr inbounds nuw %Counter, ptr %0, i32 0, i32 3
  %TotalCalls = getelementptr inbounds nuw %Counter, ptr %0, i32 0, i32 4
  %load_TotalCalls = load i16, ptr %TotalCalls, align 2, !dbg !39
  %1 = sext i16 %load_TotalCalls to i32, !dbg !39
  %tmpVar = add i32 %1, 1, !dbg !39
  %2 = trunc i32 %tmpVar to i16, !dbg !39
  store i16 %2, ptr %TotalCalls, align 2, !dbg !39
  %load_Reset = load i8, ptr %Reset, align 1, !dbg !40
  %3 = icmp ne i8 %load_Reset, 0, !dbg !40
  br i1 %3, label %condition_body, label %else, !dbg !40

condition_body:                                   ; preds = %entry
  store i16 0, ptr %Value, align 2, !dbg !41
  br label %continue, !dbg !42

else:                                             ; preds = %entry
  %load_Value = load i16, ptr %Value, align 2, !dbg !43
  %4 = sext i16 %load_Value to i32, !dbg !43
  %load_Increment = load i16, ptr %Increment, align 2, !dbg !43
  %5 = sext i16 %load_Increment to i32, !dbg !43
  %tmpVar1 = add i32 %4, %5, !dbg !43
  %6 = trunc i32 %tmpVar1 to i16, !dbg !43
  store i16 %6, ptr %Value, align 2, !dbg !43
  br label %continue, !dbg !42

continue:                                         ; preds = %else, %condition_body
  ret void, !dbg !44
}

define void @HarnessTest(ptr %0) !dbg !45 {
entry:
    #dbg_declare(ptr %0, !48, !DIExpression(), !49)
  %A = getelementptr inbounds nuw %HarnessTest, ptr %0, i32 0, i32 0
  %B = getelementptr inbounds nuw %HarnessTest, ptr %0, i32 0, i32 1
  %Flag = getelementptr inbounds nuw %HarnessTest, ptr %0, i32 0, i32 2
  %Index = getelementptr inbounds nuw %HarnessTest, ptr %0, i32 0, i32 3
  %Sum = getelementptr inbounds nuw %HarnessTest, ptr %0, i32 0, i32 4
  %Product = getelementptr inbounds nuw %HarnessTest, ptr %0, i32 0, i32 5
  %Buf = getelementptr inbounds nuw %HarnessTest, ptr %0, i32 0, i32 6
  %C = getelementptr inbounds nuw %HarnessTest, ptr %0, i32 0, i32 7
  %CycleNum = getelementptr inbounds nuw %HarnessTest, ptr %0, i32 0, i32 8
  %load_CycleNum = load i16, ptr %CycleNum, align 2, !dbg !49
  %1 = sext i16 %load_CycleNum to i32, !dbg !49
  %tmpVar = add i32 %1, 1, !dbg !49
  %2 = trunc i32 %tmpVar to i16, !dbg !49
  store i16 %2, ptr %CycleNum, align 2, !dbg !49
  %load_A = load i16, ptr %A, align 2, !dbg !50
  %3 = sext i16 %load_A to i32, !dbg !50
  %load_B = load i16, ptr %B, align 2, !dbg !50
  %4 = sext i16 %load_B to i32, !dbg !50
  %tmpVar1 = add i32 %3, %4, !dbg !50
  %5 = trunc i32 %tmpVar1 to i16, !dbg !50
  store i16 %5, ptr %Sum, align 2, !dbg !50
  %load_A2 = load i16, ptr %A, align 2, !dbg !51
  %6 = sext i16 %load_A2 to i32, !dbg !51
  %load_B3 = load i16, ptr %B, align 2, !dbg !51
  %7 = sext i16 %load_B3 to i32, !dbg !51
  %tmpVar4 = mul i32 %6, %7, !dbg !51
  store i32 %tmpVar4, ptr %Product, align 4, !dbg !51
  %load_Index = load i16, ptr %Index, align 2, !dbg !52
  %8 = sext i16 %load_Index to i32, !dbg !52
  %tmpVar5 = icmp sge i32 %8, 0, !dbg !52
  %9 = zext i1 %tmpVar5 to i8, !dbg !52
  %10 = icmp ne i8 %9, 0, !dbg !52
  %load_Index6 = load i16, ptr %Index, align 2, !dbg !52
  %11 = sext i16 %load_Index6 to i32, !dbg !52
  %tmpVar7 = icmp sle i32 %11, 15, !dbg !52
  %12 = zext i1 %tmpVar7 to i8, !dbg !52
  %13 = icmp ne i8 %12, 0, !dbg !52
  %14 = and i1 %10, %13, !dbg !52
  %15 = zext i1 %14 to i8, !dbg !52
  %16 = icmp ne i8 %15, 0, !dbg !52
  br i1 %16, label %condition_body, label %continue, !dbg !52

condition_body:                                   ; preds = %entry
  %load_Index8 = load i16, ptr %Index, align 2, !dbg !53
  %17 = sext i16 %load_Index8 to i32, !dbg !53
  %tmpVar9 = mul i32 1, %17, !dbg !53
  %tmpVar10 = add i32 %tmpVar9, 0, !dbg !53
  %tmpVar11 = getelementptr inbounds [16 x i16], ptr %Buf, i32 0, i32 %tmpVar10, !dbg !53
  %load_Sum = load i16, ptr %Sum, align 2, !dbg !53
  store i16 %load_Sum, ptr %tmpVar11, align 2, !dbg !53
  br label %continue, !dbg !54

continue:                                         ; preds = %condition_body, %entry
  %18 = getelementptr inbounds %Counter, ptr %C, i32 0, i32 1, !dbg !54
  %load_A12 = load i16, ptr %A, align 2, !dbg !54
  store i16 %load_A12, ptr %18, align 2, !dbg !54
  %19 = getelementptr inbounds %Counter, ptr %C, i32 0, i32 2, !dbg !54
  %load_Flag = load i8, ptr %Flag, align 1, !dbg !54
  store i8 %load_Flag, ptr %19, align 1, !dbg !54
  call void @Counter(ptr %C), !dbg !55
  ret void, !dbg !56
}

define void @Counter__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !56
  store ptr %0, ptr %self, align 8, !dbg !56
  %deref = load ptr, ptr %self, align 8, !dbg !56
  %__vtable = getelementptr inbounds nuw %Counter, ptr %deref, i32 0, i32 0, !dbg !56
  call void @__Counter___vtable__ctor(ptr %__vtable), !dbg !56
  %deref1 = load ptr, ptr %self, align 8, !dbg !56
  %__vtable2 = getelementptr inbounds nuw %Counter, ptr %deref1, i32 0, i32 0, !dbg !56
  store ptr @__vtable_Counter_instance, ptr %__vtable2, align 8, !dbg !56
  ret void, !dbg !56
}

define void @HarnessTest__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !56
  store ptr %0, ptr %self, align 8, !dbg !56
  %deref = load ptr, ptr %self, align 8, !dbg !56
  %Buf = getelementptr inbounds nuw %HarnessTest, ptr %deref, i32 0, i32 6, !dbg !56
  call void @__HarnessTest_Buf__ctor(ptr %Buf), !dbg !56
  %deref1 = load ptr, ptr %self, align 8, !dbg !56
  %C = getelementptr inbounds nuw %HarnessTest, ptr %deref1, i32 0, i32 7, !dbg !56
  call void @Counter__ctor(ptr %C), !dbg !56
  ret void, !dbg !56
}

define void @__HarnessTest_Buf__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !56
  store ptr %0, ptr %self, align 8, !dbg !56
  ret void, !dbg !56
}

define void @__vtable_Counter__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !56
  store ptr %0, ptr %self, align 8, !dbg !56
  %deref = load ptr, ptr %self, align 8, !dbg !56
  %__body = getelementptr inbounds nuw %__vtable_Counter, ptr %deref, i32 0, i32 0, !dbg !56
  call void @____vtable_Counter___body__ctor(ptr %__body), !dbg !56
  %deref1 = load ptr, ptr %self, align 8, !dbg !56
  %__body2 = getelementptr inbounds nuw %__vtable_Counter, ptr %deref1, i32 0, i32 0, !dbg !56
  store ptr @Counter, ptr %__body2, align 8, !dbg !56
  ret void, !dbg !56
}

define void @__Counter___vtable__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !56
  store ptr %0, ptr %self, align 8, !dbg !56
  ret void, !dbg !56
}

define void @____vtable_Counter___body__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !56
  store ptr %0, ptr %self, align 8, !dbg !56
  ret void, !dbg !56
}

define void @__unit_harness_test_st__ctor() {
entry:
  call void @__vtable_Counter__ctor(ptr @__vtable_Counter_instance), !dbg !56
  call void @HarnessTest__ctor(ptr @HarnessTest_instance), !dbg !56
  ret void, !dbg !56
}

!llvm.module.flags = !{!30, !31}
!llvm.dbg.cu = !{!32}

!0 = !DIGlobalVariableExpression(var: !1, expr: !DIExpression())
!1 = distinct !DIGlobalVariable(name: "HarnessTest", scope: !2, file: !2, line: 20, type: !3, isLocal: false, isDefinition: true)
!2 = !DIFile(filename: "benchmarks/harness_test.st", directory: "/workspaces/ICSPrism")
!3 = !DICompositeType(tag: DW_TAG_structure_type, name: "HarnessTest", scope: !2, file: !2, line: 20, size: 576, align: 64, flags: DIFlagPublic, elements: !4, identifier: "HarnessTest")
!4 = !{!5, !7, !8, !10, !11, !12, !14, !18, !29}
!5 = !DIDerivedType(tag: DW_TAG_member, name: "A", scope: !2, file: !2, line: 22, baseType: !6, size: 16, align: 16, flags: DIFlagPublic)
!6 = !DIBasicType(name: "INT", size: 16, encoding: DW_ATE_signed, flags: DIFlagPublic)
!7 = !DIDerivedType(tag: DW_TAG_member, name: "B", scope: !2, file: !2, line: 23, baseType: !6, size: 16, align: 16, offset: 16, flags: DIFlagPublic)
!8 = !DIDerivedType(tag: DW_TAG_member, name: "Flag", scope: !2, file: !2, line: 24, baseType: !9, size: 8, align: 8, offset: 32, flags: DIFlagPublic)
!9 = !DIBasicType(name: "BOOL", size: 8, encoding: DW_ATE_boolean, flags: DIFlagPublic)
!10 = !DIDerivedType(tag: DW_TAG_member, name: "Index", scope: !2, file: !2, line: 25, baseType: !6, size: 16, align: 16, offset: 48, flags: DIFlagPublic)
!11 = !DIDerivedType(tag: DW_TAG_member, name: "Sum", scope: !2, file: !2, line: 28, baseType: !6, size: 16, align: 16, offset: 64, flags: DIFlagPublic)
!12 = !DIDerivedType(tag: DW_TAG_member, name: "Product", scope: !2, file: !2, line: 29, baseType: !13, size: 32, align: 32, offset: 96, flags: DIFlagPublic)
!13 = !DIBasicType(name: "DINT", size: 32, encoding: DW_ATE_signed, flags: DIFlagPublic)
!14 = !DIDerivedType(tag: DW_TAG_member, name: "Buf", scope: !2, file: !2, line: 30, baseType: !15, size: 256, align: 16, offset: 128, flags: DIFlagPublic)
!15 = !DICompositeType(tag: DW_TAG_array_type, baseType: !6, size: 256, align: 16, elements: !16)
!16 = !{!17}
!17 = !DISubrange(count: 16, lowerBound: 0)
!18 = !DIDerivedType(tag: DW_TAG_member, name: "C", scope: !2, file: !2, line: 31, baseType: !19, size: 128, align: 64, offset: 384, flags: DIFlagPublic)
!19 = !DICompositeType(tag: DW_TAG_structure_type, name: "Counter", scope: !2, file: !2, line: 1, size: 128, align: 64, flags: DIFlagPublic, elements: !20, identifier: "Counter")
!20 = !{!21, !25, !26, !27, !28}
!21 = !DIDerivedType(tag: DW_TAG_member, name: "__vtable", scope: !2, file: !2, baseType: !22, size: 64, align: 64, flags: DIFlagPublic)
!22 = !DIDerivedType(tag: DW_TAG_typedef, name: "__POINTER_TO____Counter___vtable", scope: !2, file: !2, baseType: !23, align: 64)
!23 = !DIDerivedType(tag: DW_TAG_pointer_type, name: "__Counter___vtable", baseType: !24, size: 64, align: 64, dwarfAddressSpace: 1)
!24 = !DIBasicType(name: "__VOID", encoding: DW_ATE_unsigned, flags: DIFlagPublic)
!25 = !DIDerivedType(tag: DW_TAG_member, name: "Increment", scope: !2, file: !2, line: 3, baseType: !6, size: 16, align: 16, offset: 64, flags: DIFlagPublic)
!26 = !DIDerivedType(tag: DW_TAG_member, name: "Reset", scope: !2, file: !2, line: 4, baseType: !9, size: 8, align: 8, offset: 80, flags: DIFlagPublic)
!27 = !DIDerivedType(tag: DW_TAG_member, name: "Value", scope: !2, file: !2, line: 7, baseType: !6, size: 16, align: 16, offset: 96, flags: DIFlagPublic)
!28 = !DIDerivedType(tag: DW_TAG_member, name: "TotalCalls", scope: !2, file: !2, line: 8, baseType: !6, size: 16, align: 16, offset: 112, flags: DIFlagPublic)
!29 = !DIDerivedType(tag: DW_TAG_member, name: "CycleNum", scope: !2, file: !2, line: 32, baseType: !6, size: 16, align: 16, offset: 512, flags: DIFlagPublic)
!30 = !{i32 2, !"Dwarf Version", i32 5}
!31 = !{i32 2, !"Debug Info Version", i32 3}
!32 = distinct !DICompileUnit(language: DW_LANG_C, file: !2, producer: "RuSTy Structured text Compiler", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, globals: !33, splitDebugInlining: false)
!33 = !{!0}
!34 = distinct !DISubprogram(name: "Counter", linkageName: "Counter", scope: !2, file: !2, line: 1, type: !35, scopeLine: 11, flags: DIFlagPublic, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !32, retainedNodes: !37)
!35 = !DISubroutineType(flags: DIFlagPublic, types: !36)
!36 = !{null, !19, !6, !9}
!37 = !{}
!38 = !DILocalVariable(name: "Counter", scope: !34, file: !2, line: 11, type: !19)
!39 = !DILocation(line: 11, scope: !34)
!40 = !DILocation(line: 12, column: 3, scope: !34)
!41 = !DILocation(line: 13, column: 4, scope: !34)
!42 = !DILocation(line: 16, scope: !34)
!43 = !DILocation(line: 15, column: 4, scope: !34)
!44 = !DILocation(line: 17, scope: !34)
!45 = distinct !DISubprogram(name: "HarnessTest", linkageName: "HarnessTest", scope: !2, file: !2, line: 20, type: !46, scopeLine: 36, flags: DIFlagPublic, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !32, retainedNodes: !37)
!46 = !DISubroutineType(flags: DIFlagPublic, types: !47)
!47 = !{null, !3, !6, !6, !9, !6}
!48 = !DILocalVariable(name: "HarnessTest", scope: !45, file: !2, line: 36, type: !3)
!49 = !DILocation(line: 36, scope: !45)
!50 = !DILocation(line: 37, scope: !45)
!51 = !DILocation(line: 38, scope: !45)
!52 = !DILocation(line: 41, column: 3, scope: !45)
!53 = !DILocation(line: 42, column: 4, scope: !45)
!54 = !DILocation(line: 43, scope: !45)
!55 = !DILocation(line: 46, scope: !45)
!56 = !DILocation(line: 48, scope: !45)
