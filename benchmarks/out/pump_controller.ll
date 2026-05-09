; ModuleID = '/tmp/.tmp3gXbF7/benchmarks/pump_controller.st.ll'
source_filename = "/workspaces/ICSPrism/benchmarks/pump_controller.st"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%__vtable_PumpController = type { ptr }
%PLC_PRG = type { i8, i8, i8, i16, i16, %PumpController }
%PumpController = type { ptr, i8, i8, i8, i16, i16, i8, i16, i16, i16, i16, [8 x i16], i16, i8 }

@MODE_INIT = unnamed_addr constant i8 0, !dbg !0
@MODE_IDLE = unnamed_addr constant i8 1, !dbg !5
@MODE_ARMED = unnamed_addr constant i8 2, !dbg !7
@MODE_RUN = unnamed_addr constant i8 3, !dbg !9
@MODE_FAULT = unnamed_addr constant i8 4, !dbg !11
@__vtable_PumpController_instance = global %__vtable_PumpController zeroinitializer
@PLC_PRG_instance = global %PLC_PRG zeroinitializer, !dbg !13
@llvm.global_ctors = appending global [1 x { i32, ptr, ptr }] [{ i32, ptr, ptr } { i32 65535, ptr @__unit_pump_controller_st__ctor, ptr null }]

define void @PumpController(ptr %0) !dbg !51 {
entry:
    #dbg_declare(ptr %0, !55, !DIExpression(), !56)
  %this = alloca ptr, align 8
  store ptr %0, ptr %this, align 8
  %__vtable = getelementptr inbounds nuw %PumpController, ptr %0, i32 0, i32 0
  %CmdArm = getelementptr inbounds nuw %PumpController, ptr %0, i32 0, i32 1
  %CmdStart = getelementptr inbounds nuw %PumpController, ptr %0, i32 0, i32 2
  %CmdReset = getelementptr inbounds nuw %PumpController, ptr %0, i32 0, i32 3
  %Pressure = getelementptr inbounds nuw %PumpController, ptr %0, i32 0, i32 4
  %Temp = getelementptr inbounds nuw %PumpController, ptr %0, i32 0, i32 5
  %Mode = getelementptr inbounds nuw %PumpController, ptr %0, i32 0, i32 6
  %CycleCount = getelementptr inbounds nuw %PumpController, ptr %0, i32 0, i32 7
  %PressureScore = getelementptr inbounds nuw %PumpController, ptr %0, i32 0, i32 8
  %ArmedCycles = getelementptr inbounds nuw %PumpController, ptr %0, i32 0, i32 9
  %Offset = getelementptr inbounds nuw %PumpController, ptr %0, i32 0, i32 10
  %Buffer = getelementptr inbounds nuw %PumpController, ptr %0, i32 0, i32 11
  %i = getelementptr inbounds nuw %PumpController, ptr %0, i32 0, i32 12
  %Status = getelementptr inbounds nuw %PumpController, ptr %0, i32 0, i32 13
  %load_CycleCount = load i16, ptr %CycleCount, align 2, !dbg !56
  %1 = sext i16 %load_CycleCount to i32, !dbg !56
  %tmpVar = add i32 %1, 1, !dbg !56
  %2 = trunc i32 %tmpVar to i16, !dbg !56
  store i16 %2, ptr %CycleCount, align 2, !dbg !56
  %load_Mode = load i8, ptr %Mode, align 1, !dbg !56
  %ran_once_0 = alloca i8, align 1
  %is_incrementing_0 = alloca i8, align 1
  switch i8 %load_Mode, label %else [
    i8 0, label %case
    i8 1, label %case20
    i8 2, label %case25
    i8 3, label %case35
    i8 4, label %case78
  ], !dbg !57

case:                                             ; preds = %entry
  store i8 0, ptr %ran_once_0, align 1, !dbg !56
  store i8 0, ptr %is_incrementing_0, align 1, !dbg !56
  store i16 0, ptr %i, align 2, !dbg !58
  store i8 1, ptr %is_incrementing_0, align 1, !dbg !59
  br label %while_body, !dbg !59

case20:                                           ; preds = %entry
  %load_CmdReset = load i8, ptr %CmdReset, align 1, !dbg !60
  %3 = icmp ne i8 %load_CmdReset, 0, !dbg !60
  br i1 %3, label %condition_body22, label %continue21, !dbg !60

case25:                                           ; preds = %entry
  %load_ArmedCycles = load i16, ptr %ArmedCycles, align 2, !dbg !61
  %4 = sext i16 %load_ArmedCycles to i32, !dbg !61
  %tmpVar26 = add i32 %4, 1, !dbg !61
  %5 = trunc i32 %tmpVar26 to i16, !dbg !61
  store i16 %5, ptr %ArmedCycles, align 2, !dbg !61
  %load_CmdReset29 = load i8, ptr %CmdReset, align 1, !dbg !62
  %6 = icmp ne i8 %load_CmdReset29, 0, !dbg !62
  br i1 %6, label %condition_body30, label %else27, !dbg !62

case35:                                           ; preds = %entry
  %load_Pressure = load i16, ptr %Pressure, align 2, !dbg !63
  %7 = sext i16 %load_Pressure to i32, !dbg !63
  %tmpVar37 = icmp sgt i32 %7, 70, !dbg !63
  %8 = zext i1 %tmpVar37 to i8, !dbg !63
  %9 = icmp ne i8 %8, 0, !dbg !63
  br i1 %9, label %condition_body38, label %continue36, !dbg !63

case78:                                           ; preds = %entry
  %load_CmdReset80 = load i8, ptr %CmdReset, align 1, !dbg !64
  %10 = icmp ne i8 %load_CmdReset80, 0, !dbg !64
  br i1 %10, label %condition_body81, label %continue79, !dbg !64

else:                                             ; preds = %entry
  br label %continue, !dbg !65

continue:                                         ; preds = %continue79, %continue74, %continue28, %continue23, %continue1, %else
  %load_Mode82 = load i8, ptr %Mode, align 1, !dbg !66
  store i8 %load_Mode82, ptr %Status, align 1, !dbg !66
  ret void, !dbg !67

while_body:                                       ; preds = %continue5, %case
  %load_ran_once_0 = load i8, ptr %ran_once_0, align 1, !dbg !59
  %11 = icmp ne i8 %load_ran_once_0, 0, !dbg !59
  br i1 %11, label %condition_body, label %continue2, !dbg !59

continue1:                                        ; preds = %condition_body14, %condition_body10
  store i16 0, ptr %PressureScore, align 2, !dbg !68
  store i16 0, ptr %ArmedCycles, align 2, !dbg !69
  store i16 0, ptr %Offset, align 2, !dbg !70
  store i8 1, ptr %Mode, align 1, !dbg !71
  br label %continue, !dbg !65

condition_body:                                   ; preds = %while_body
  %load_i = load i16, ptr %i, align 2, !dbg !58
  %12 = sext i16 %load_i to i32, !dbg !58
  %tmpVar3 = add i32 %12, 1, !dbg !58
  %13 = trunc i32 %tmpVar3 to i16, !dbg !58
  store i16 %13, ptr %i, align 2, !dbg !58
  br label %continue2, !dbg !59

continue2:                                        ; preds = %condition_body, %while_body
  store i8 1, ptr %ran_once_0, align 1, !dbg !59
  %load_is_incrementing_0 = load i8, ptr %is_incrementing_0, align 1, !dbg !59
  %14 = icmp ne i8 %load_is_incrementing_0, 0, !dbg !59
  br i1 %14, label %condition_body6, label %else4, !dbg !59

condition_body6:                                  ; preds = %continue2
  %load_i8 = load i16, ptr %i, align 2, !dbg !58
  %15 = sext i16 %load_i8 to i32, !dbg !58
  %tmpVar9 = icmp sgt i32 %15, 7, !dbg !58
  %16 = zext i1 %tmpVar9 to i8, !dbg !58
  %17 = icmp ne i8 %16, 0, !dbg !58
  br i1 %17, label %condition_body10, label %continue7, !dbg !58

else4:                                            ; preds = %continue2
  %load_i12 = load i16, ptr %i, align 2, !dbg !58
  %18 = sext i16 %load_i12 to i32, !dbg !58
  %tmpVar13 = icmp slt i32 %18, 7, !dbg !58
  %19 = zext i1 %tmpVar13 to i8, !dbg !58
  %20 = icmp ne i8 %19, 0, !dbg !58
  br i1 %20, label %condition_body14, label %continue11, !dbg !58

continue5:                                        ; preds = %continue11, %continue7
  %load_i16 = load i16, ptr %i, align 2, !dbg !72
  %21 = sext i16 %load_i16 to i32, !dbg !72
  %tmpVar17 = mul i32 1, %21, !dbg !72
  %tmpVar18 = add i32 %tmpVar17, 0, !dbg !72
  %tmpVar19 = getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 %tmpVar18, !dbg !72
  store i16 0, ptr %tmpVar19, align 2, !dbg !72
  br label %while_body, !dbg !59

condition_body10:                                 ; preds = %condition_body6
  br label %continue1, !dbg !59

buffer_block:                                     ; No predecessors!
  br label %continue7, !dbg !59

continue7:                                        ; preds = %buffer_block, %condition_body6
  br label %continue5, !dbg !59

condition_body14:                                 ; preds = %else4
  br label %continue1, !dbg !59

buffer_block15:                                   ; No predecessors!
  br label %continue11, !dbg !59

continue11:                                       ; preds = %buffer_block15, %else4
  br label %continue5, !dbg !59

condition_body22:                                 ; preds = %case20
  store i16 0, ptr %PressureScore, align 2, !dbg !73
  store i16 0, ptr %ArmedCycles, align 2, !dbg !74
  store i16 0, ptr %Offset, align 2, !dbg !75
  br label %continue21, !dbg !76

continue21:                                       ; preds = %condition_body22, %case20
  %load_CmdArm = load i8, ptr %CmdArm, align 1, !dbg !77
  %22 = icmp ne i8 %load_CmdArm, 0, !dbg !77
  br i1 %22, label %condition_body24, label %continue23, !dbg !77

condition_body24:                                 ; preds = %continue21
  store i8 2, ptr %Mode, align 1, !dbg !78
  store i16 0, ptr %ArmedCycles, align 2, !dbg !79
  br label %continue23, !dbg !80

continue23:                                       ; preds = %condition_body24, %continue21
  br label %continue, !dbg !65

condition_body30:                                 ; preds = %case25
  store i8 1, ptr %Mode, align 1, !dbg !81
  store i16 0, ptr %PressureScore, align 2, !dbg !82
  store i16 0, ptr %ArmedCycles, align 2, !dbg !83
  store i16 0, ptr %Offset, align 2, !dbg !84
  br label %continue28, !dbg !85

else27:                                           ; preds = %case25
  %load_CmdStart = load i8, ptr %CmdStart, align 1, !dbg !86
  %23 = icmp ne i8 %load_CmdStart, 0, !dbg !86
  %load_ArmedCycles32 = load i16, ptr %ArmedCycles, align 2, !dbg !86
  %24 = sext i16 %load_ArmedCycles32 to i32, !dbg !86
  %tmpVar33 = icmp sge i32 %24, 3, !dbg !86
  %25 = zext i1 %tmpVar33 to i8, !dbg !86
  %26 = icmp ne i8 %25, 0, !dbg !86
  %27 = and i1 %23, %26, !dbg !86
  %28 = zext i1 %27 to i8, !dbg !86
  %29 = icmp ne i8 %28, 0, !dbg !86
  br i1 %29, label %condition_body34, label %continue31, !dbg !86

continue28:                                       ; preds = %continue31, %condition_body30
  br label %continue, !dbg !65

condition_body34:                                 ; preds = %else27
  store i8 3, ptr %Mode, align 1, !dbg !87
  br label %continue31, !dbg !85

continue31:                                       ; preds = %condition_body34, %else27
  br label %continue28, !dbg !85

condition_body38:                                 ; preds = %case35
  %load_PressureScore = load i16, ptr %PressureScore, align 2, !dbg !88
  %30 = sext i16 %load_PressureScore to i32, !dbg !88
  %tmpVar39 = add i32 %30, 1, !dbg !88
  %31 = trunc i32 %tmpVar39 to i16, !dbg !88
  store i16 %31, ptr %PressureScore, align 2, !dbg !88
  br label %continue36, !dbg !89

continue36:                                       ; preds = %condition_body38, %case35
  %load_Temp = load i16, ptr %Temp, align 2, !dbg !90
  %32 = sext i16 %load_Temp to i32, !dbg !90
  %tmpVar41 = icmp sgt i32 %32, 50, !dbg !90
  %33 = zext i1 %tmpVar41 to i8, !dbg !90
  %34 = icmp ne i8 %33, 0, !dbg !90
  %load_Temp42 = load i16, ptr %Temp, align 2, !dbg !90
  %35 = sext i16 %load_Temp42 to i32, !dbg !90
  %tmpVar43 = icmp slt i32 %35, 60, !dbg !90
  %36 = zext i1 %tmpVar43 to i8, !dbg !90
  %37 = icmp ne i8 %36, 0, !dbg !90
  %38 = and i1 %34, %37, !dbg !90
  %39 = zext i1 %38 to i8, !dbg !90
  %40 = icmp ne i8 %39, 0, !dbg !90
  br i1 %40, label %condition_body44, label %continue40, !dbg !90

condition_body44:                                 ; preds = %continue36
  %load_Offset = load i16, ptr %Offset, align 2, !dbg !91
  %41 = sext i16 %load_Offset to i32, !dbg !91
  %tmpVar45 = add i32 %41, 1, !dbg !91
  %42 = trunc i32 %tmpVar45 to i16, !dbg !91
  store i16 %42, ptr %Offset, align 2, !dbg !91
  br label %continue40, !dbg !92

continue40:                                       ; preds = %condition_body44, %continue36
  %load_PressureScore47 = load i16, ptr %PressureScore, align 2, !dbg !93
  %43 = sext i16 %load_PressureScore47 to i32, !dbg !93
  %tmpVar48 = icmp sge i32 %43, 4, !dbg !93
  %44 = zext i1 %tmpVar48 to i8, !dbg !93
  %45 = icmp ne i8 %44, 0, !dbg !93
  br i1 %45, label %condition_body49, label %continue46, !dbg !93

condition_body49:                                 ; preds = %continue40
  %tmpVar50 = getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 0, !dbg !94
  %tmpVar51 = getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 0, !dbg !94
  %load_tmpVar = load i16, ptr %tmpVar51, align 2, !dbg !94
  %46 = sext i16 %load_tmpVar to i32, !dbg !94
  %tmpVar52 = add i32 %46, 1, !dbg !94
  %47 = trunc i32 %tmpVar52 to i16, !dbg !94
  store i16 %47, ptr %tmpVar50, align 2, !dbg !94
  br label %continue46, !dbg !95

continue46:                                       ; preds = %condition_body49, %continue40
  %tmpVar54 = getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 0, !dbg !96
  %load_tmpVar55 = load i16, ptr %tmpVar54, align 2, !dbg !96
  %48 = sext i16 %load_tmpVar55 to i32, !dbg !96
  %tmpVar56 = icmp sgt i32 %48, 2, !dbg !96
  %49 = zext i1 %tmpVar56 to i8, !dbg !96
  %50 = icmp ne i8 %49, 0, !dbg !96
  br i1 %50, label %condition_body57, label %continue53, !dbg !96

condition_body57:                                 ; preds = %continue46
  %tmpVar58 = getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 1, !dbg !97
  %tmpVar59 = getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 1, !dbg !97
  %load_tmpVar60 = load i16, ptr %tmpVar59, align 2, !dbg !97
  %51 = sext i16 %load_tmpVar60 to i32, !dbg !97
  %tmpVar61 = add i32 %51, 1, !dbg !97
  %52 = trunc i32 %tmpVar61 to i16, !dbg !97
  store i16 %52, ptr %tmpVar58, align 2, !dbg !97
  br label %continue53, !dbg !98

continue53:                                       ; preds = %condition_body57, %continue46
  %tmpVar63 = getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 1, !dbg !99
  %load_tmpVar64 = load i16, ptr %tmpVar63, align 2, !dbg !99
  %53 = sext i16 %load_tmpVar64 to i32, !dbg !99
  %tmpVar65 = icmp sgt i32 %53, 1, !dbg !99
  %54 = zext i1 %tmpVar65 to i8, !dbg !99
  %55 = icmp ne i8 %54, 0, !dbg !99
  br i1 %55, label %condition_body66, label %continue62, !dbg !99

condition_body66:                                 ; preds = %continue53
  %load_Offset67 = load i16, ptr %Offset, align 2, !dbg !100
  %56 = sext i16 %load_Offset67 to i32, !dbg !100
  %tmpVar68 = mul i32 1, %56, !dbg !100
  %tmpVar69 = add i32 %tmpVar68, 0, !dbg !100
  %tmpVar70 = getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 %tmpVar69, !dbg !100
  store i16 1234, ptr %tmpVar70, align 2, !dbg !100
  br label %continue62, !dbg !101

continue62:                                       ; preds = %condition_body66, %continue53
  %load_CmdReset72 = load i8, ptr %CmdReset, align 1, !dbg !102
  %57 = icmp ne i8 %load_CmdReset72, 0, !dbg !102
  br i1 %57, label %condition_body73, label %continue71, !dbg !102

condition_body73:                                 ; preds = %continue62
  store i8 1, ptr %Mode, align 1, !dbg !103
  store i16 0, ptr %PressureScore, align 2, !dbg !104
  store i16 0, ptr %ArmedCycles, align 2, !dbg !105
  store i16 0, ptr %Offset, align 2, !dbg !106
  br label %continue71, !dbg !107

continue71:                                       ; preds = %condition_body73, %continue62
  %load_Temp75 = load i16, ptr %Temp, align 2, !dbg !108
  %58 = sext i16 %load_Temp75 to i32, !dbg !108
  %tmpVar76 = icmp sgt i32 %58, 90, !dbg !108
  %59 = zext i1 %tmpVar76 to i8, !dbg !108
  %60 = icmp ne i8 %59, 0, !dbg !108
  br i1 %60, label %condition_body77, label %continue74, !dbg !108

condition_body77:                                 ; preds = %continue71
  store i8 4, ptr %Mode, align 1, !dbg !109
  br label %continue74, !dbg !110

continue74:                                       ; preds = %condition_body77, %continue71
  br label %continue, !dbg !65

condition_body81:                                 ; preds = %case78
  store i8 1, ptr %Mode, align 1, !dbg !111
  store i16 0, ptr %PressureScore, align 2, !dbg !112
  store i16 0, ptr %ArmedCycles, align 2, !dbg !113
  store i16 0, ptr %Offset, align 2, !dbg !114
  br label %continue79, !dbg !115

continue79:                                       ; preds = %condition_body81, %case78
  br label %continue, !dbg !65
}

define void @PLC_PRG(ptr %0) !dbg !116 {
entry:
    #dbg_declare(ptr %0, !119, !DIExpression(), !120)
  %CmdArm = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 0
  %CmdStart = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 1
  %CmdReset = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 2
  %Pressure = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 3
  %Temp = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 4
  %Controller = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 5
  %1 = getelementptr inbounds %PumpController, ptr %Controller, i32 0, i32 1, !dbg !120
  %load_CmdArm = load i8, ptr %CmdArm, align 1, !dbg !120
  store i8 %load_CmdArm, ptr %1, align 1, !dbg !120
  %2 = getelementptr inbounds %PumpController, ptr %Controller, i32 0, i32 2, !dbg !120
  %load_CmdStart = load i8, ptr %CmdStart, align 1, !dbg !120
  store i8 %load_CmdStart, ptr %2, align 1, !dbg !120
  %3 = getelementptr inbounds %PumpController, ptr %Controller, i32 0, i32 3, !dbg !120
  %load_CmdReset = load i8, ptr %CmdReset, align 1, !dbg !120
  store i8 %load_CmdReset, ptr %3, align 1, !dbg !120
  %4 = getelementptr inbounds %PumpController, ptr %Controller, i32 0, i32 4, !dbg !120
  %load_Pressure = load i16, ptr %Pressure, align 2, !dbg !120
  store i16 %load_Pressure, ptr %4, align 2, !dbg !120
  %5 = getelementptr inbounds %PumpController, ptr %Controller, i32 0, i32 5, !dbg !120
  %load_Temp = load i16, ptr %Temp, align 2, !dbg !120
  store i16 %load_Temp, ptr %5, align 2, !dbg !120
  call void @PumpController(ptr %Controller), !dbg !120
  ret void, !dbg !121
}

define void @PLC_PRG__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !67
  store ptr %0, ptr %self, align 8, !dbg !67
  %deref = load ptr, ptr %self, align 8, !dbg !67
  %CmdArm = getelementptr inbounds nuw %PLC_PRG, ptr %deref, i32 0, i32 0, !dbg !67
  store i8 0, ptr %CmdArm, align 1, !dbg !67
  %deref1 = load ptr, ptr %self, align 8, !dbg !67
  %CmdStart = getelementptr inbounds nuw %PLC_PRG, ptr %deref1, i32 0, i32 1, !dbg !67
  store i8 0, ptr %CmdStart, align 1, !dbg !67
  %deref2 = load ptr, ptr %self, align 8, !dbg !67
  %CmdReset = getelementptr inbounds nuw %PLC_PRG, ptr %deref2, i32 0, i32 2, !dbg !67
  store i8 0, ptr %CmdReset, align 1, !dbg !67
  %deref3 = load ptr, ptr %self, align 8, !dbg !67
  %Pressure = getelementptr inbounds nuw %PLC_PRG, ptr %deref3, i32 0, i32 3, !dbg !67
  store i16 0, ptr %Pressure, align 2, !dbg !67
  %deref4 = load ptr, ptr %self, align 8, !dbg !67
  %Temp = getelementptr inbounds nuw %PLC_PRG, ptr %deref4, i32 0, i32 4, !dbg !67
  store i16 0, ptr %Temp, align 2, !dbg !67
  %deref5 = load ptr, ptr %self, align 8, !dbg !67
  %Controller = getelementptr inbounds nuw %PLC_PRG, ptr %deref5, i32 0, i32 5, !dbg !67
  call void @PumpController__ctor(ptr %Controller), !dbg !67
  ret void, !dbg !67
}

define void @PumpController__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !67
  store ptr %0, ptr %self, align 8, !dbg !67
  %deref = load ptr, ptr %self, align 8, !dbg !67
  %__vtable = getelementptr inbounds nuw %PumpController, ptr %deref, i32 0, i32 0, !dbg !67
  call void @__PumpController___vtable__ctor(ptr %__vtable), !dbg !67
  %deref1 = load ptr, ptr %self, align 8, !dbg !67
  %Mode = getelementptr inbounds nuw %PumpController, ptr %deref1, i32 0, i32 6, !dbg !67
  store i8 0, ptr %Mode, align 1, !dbg !67
  %deref2 = load ptr, ptr %self, align 8, !dbg !67
  %CycleCount = getelementptr inbounds nuw %PumpController, ptr %deref2, i32 0, i32 7, !dbg !67
  store i16 0, ptr %CycleCount, align 2, !dbg !67
  %deref3 = load ptr, ptr %self, align 8, !dbg !67
  %PressureScore = getelementptr inbounds nuw %PumpController, ptr %deref3, i32 0, i32 8, !dbg !67
  store i16 0, ptr %PressureScore, align 2, !dbg !67
  %deref4 = load ptr, ptr %self, align 8, !dbg !67
  %ArmedCycles = getelementptr inbounds nuw %PumpController, ptr %deref4, i32 0, i32 9, !dbg !67
  store i16 0, ptr %ArmedCycles, align 2, !dbg !67
  %deref5 = load ptr, ptr %self, align 8, !dbg !67
  %Offset = getelementptr inbounds nuw %PumpController, ptr %deref5, i32 0, i32 10, !dbg !67
  store i16 0, ptr %Offset, align 2, !dbg !67
  %deref6 = load ptr, ptr %self, align 8, !dbg !67
  %Buffer = getelementptr inbounds nuw %PumpController, ptr %deref6, i32 0, i32 11, !dbg !67
  call void @__PumpController_Buffer__ctor(ptr %Buffer), !dbg !67
  %deref7 = load ptr, ptr %self, align 8, !dbg !67
  %__vtable8 = getelementptr inbounds nuw %PumpController, ptr %deref7, i32 0, i32 0, !dbg !67
  store ptr @__vtable_PumpController_instance, ptr %__vtable8, align 8, !dbg !67
  ret void, !dbg !67
}

define void @__PumpController_Buffer__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !67
  store ptr %0, ptr %self, align 8, !dbg !67
  ret void, !dbg !67
}

define void @__vtable_PumpController__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !67
  store ptr %0, ptr %self, align 8, !dbg !67
  %deref = load ptr, ptr %self, align 8, !dbg !67
  %__body = getelementptr inbounds nuw %__vtable_PumpController, ptr %deref, i32 0, i32 0, !dbg !67
  call void @____vtable_PumpController___body__ctor(ptr %__body), !dbg !67
  %deref1 = load ptr, ptr %self, align 8, !dbg !67
  %__body2 = getelementptr inbounds nuw %__vtable_PumpController, ptr %deref1, i32 0, i32 0, !dbg !67
  store ptr @PumpController, ptr %__body2, align 8, !dbg !67
  ret void, !dbg !67
}

define void @__PumpController___vtable__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !67
  store ptr %0, ptr %self, align 8, !dbg !67
  ret void, !dbg !67
}

define void @____vtable_PumpController___body__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8, !dbg !67
  store ptr %0, ptr %self, align 8, !dbg !67
  ret void, !dbg !67
}

define void @__unit_pump_controller_st__ctor() {
entry:
  call void @__vtable_PumpController__ctor(ptr @__vtable_PumpController_instance), !dbg !67
  call void @PLC_PRG__ctor(ptr @PLC_PRG_instance), !dbg !67
  ret void, !dbg !67
}

!llvm.module.flags = !{!47, !48}
!llvm.dbg.cu = !{!49}

!0 = !DIGlobalVariableExpression(var: !1, expr: !DIExpression())
!1 = distinct !DIGlobalVariable(name: "MODE_INIT", scope: !2, file: !2, line: 2, type: !3, isLocal: false, isDefinition: true)
!2 = !DIFile(filename: "benchmarks/pump_controller.st", directory: "/workspaces/ICSPrism")
!3 = !DIDerivedType(tag: DW_TAG_const_type, baseType: !4)
!4 = !DIBasicType(name: "SINT", size: 8, encoding: DW_ATE_signed, flags: DIFlagPublic)
!5 = !DIGlobalVariableExpression(var: !6, expr: !DIExpression())
!6 = distinct !DIGlobalVariable(name: "MODE_IDLE", scope: !2, file: !2, line: 3, type: !3, isLocal: false, isDefinition: true)
!7 = !DIGlobalVariableExpression(var: !8, expr: !DIExpression())
!8 = distinct !DIGlobalVariable(name: "MODE_ARMED", scope: !2, file: !2, line: 4, type: !3, isLocal: false, isDefinition: true)
!9 = !DIGlobalVariableExpression(var: !10, expr: !DIExpression())
!10 = distinct !DIGlobalVariable(name: "MODE_RUN", scope: !2, file: !2, line: 5, type: !3, isLocal: false, isDefinition: true)
!11 = !DIGlobalVariableExpression(var: !12, expr: !DIExpression())
!12 = distinct !DIGlobalVariable(name: "MODE_FAULT", scope: !2, file: !2, line: 6, type: !3, isLocal: false, isDefinition: true)
!13 = !DIGlobalVariableExpression(var: !14, expr: !DIExpression())
!14 = distinct !DIGlobalVariable(name: "PLC_PRG", scope: !2, file: !2, line: 9, type: !15, isLocal: false, isDefinition: true)
!15 = !DICompositeType(tag: DW_TAG_structure_type, name: "PLC_PRG", scope: !2, file: !2, line: 9, size: 448, align: 64, flags: DIFlagPublic, elements: !16, identifier: "PLC_PRG")
!16 = !{!17, !19, !20, !21, !23, !24}
!17 = !DIDerivedType(tag: DW_TAG_member, name: "CmdArm", scope: !2, file: !2, line: 11, baseType: !18, size: 8, align: 8, flags: DIFlagPublic)
!18 = !DIBasicType(name: "BOOL", size: 8, encoding: DW_ATE_boolean, flags: DIFlagPublic)
!19 = !DIDerivedType(tag: DW_TAG_member, name: "CmdStart", scope: !2, file: !2, line: 12, baseType: !18, size: 8, align: 8, offset: 8, flags: DIFlagPublic)
!20 = !DIDerivedType(tag: DW_TAG_member, name: "CmdReset", scope: !2, file: !2, line: 13, baseType: !18, size: 8, align: 8, offset: 16, flags: DIFlagPublic)
!21 = !DIDerivedType(tag: DW_TAG_member, name: "Pressure", scope: !2, file: !2, line: 14, baseType: !22, size: 16, align: 16, offset: 32, flags: DIFlagPublic)
!22 = !DIBasicType(name: "INT", size: 16, encoding: DW_ATE_signed, flags: DIFlagPublic)
!23 = !DIDerivedType(tag: DW_TAG_member, name: "Temp", scope: !2, file: !2, line: 15, baseType: !22, size: 16, align: 16, offset: 48, flags: DIFlagPublic)
!24 = !DIDerivedType(tag: DW_TAG_member, name: "Controller", scope: !2, file: !2, line: 18, baseType: !25, size: 384, align: 64, offset: 64, flags: DIFlagPublic)
!25 = !DICompositeType(tag: DW_TAG_structure_type, name: "PumpController", scope: !2, file: !2, line: 32, size: 384, align: 64, flags: DIFlagPublic, elements: !26, identifier: "PumpController")
!26 = !{!27, !31, !32, !33, !34, !35, !36, !37, !38, !39, !40, !41, !45, !46}
!27 = !DIDerivedType(tag: DW_TAG_member, name: "__vtable", scope: !2, file: !2, baseType: !28, size: 64, align: 64, flags: DIFlagPublic)
!28 = !DIDerivedType(tag: DW_TAG_typedef, name: "__POINTER_TO____PumpController___vtable", scope: !2, file: !2, baseType: !29, align: 64)
!29 = !DIDerivedType(tag: DW_TAG_pointer_type, name: "__PumpController___vtable", baseType: !30, size: 64, align: 64, dwarfAddressSpace: 1)
!30 = !DIBasicType(name: "__VOID", encoding: DW_ATE_unsigned, flags: DIFlagPublic)
!31 = !DIDerivedType(tag: DW_TAG_member, name: "CmdArm", scope: !2, file: !2, line: 34, baseType: !18, size: 8, align: 8, offset: 64, flags: DIFlagPublic)
!32 = !DIDerivedType(tag: DW_TAG_member, name: "CmdStart", scope: !2, file: !2, line: 35, baseType: !18, size: 8, align: 8, offset: 72, flags: DIFlagPublic)
!33 = !DIDerivedType(tag: DW_TAG_member, name: "CmdReset", scope: !2, file: !2, line: 36, baseType: !18, size: 8, align: 8, offset: 80, flags: DIFlagPublic)
!34 = !DIDerivedType(tag: DW_TAG_member, name: "Pressure", scope: !2, file: !2, line: 37, baseType: !22, size: 16, align: 16, offset: 96, flags: DIFlagPublic)
!35 = !DIDerivedType(tag: DW_TAG_member, name: "Temp", scope: !2, file: !2, line: 38, baseType: !22, size: 16, align: 16, offset: 112, flags: DIFlagPublic)
!36 = !DIDerivedType(tag: DW_TAG_member, name: "Mode", scope: !2, file: !2, line: 41, baseType: !4, size: 8, align: 8, offset: 128, flags: DIFlagPublic)
!37 = !DIDerivedType(tag: DW_TAG_member, name: "CycleCount", scope: !2, file: !2, line: 42, baseType: !22, size: 16, align: 16, offset: 144, flags: DIFlagPublic)
!38 = !DIDerivedType(tag: DW_TAG_member, name: "PressureScore", scope: !2, file: !2, line: 43, baseType: !22, size: 16, align: 16, offset: 160, flags: DIFlagPublic)
!39 = !DIDerivedType(tag: DW_TAG_member, name: "ArmedCycles", scope: !2, file: !2, line: 44, baseType: !22, size: 16, align: 16, offset: 176, flags: DIFlagPublic)
!40 = !DIDerivedType(tag: DW_TAG_member, name: "Offset", scope: !2, file: !2, line: 45, baseType: !22, size: 16, align: 16, offset: 192, flags: DIFlagPublic)
!41 = !DIDerivedType(tag: DW_TAG_member, name: "Buffer", scope: !2, file: !2, line: 46, baseType: !42, size: 128, align: 16, offset: 208, flags: DIFlagPublic)
!42 = !DICompositeType(tag: DW_TAG_array_type, baseType: !22, size: 128, align: 16, elements: !43)
!43 = !{!44}
!44 = !DISubrange(count: 8, lowerBound: 0)
!45 = !DIDerivedType(tag: DW_TAG_member, name: "i", scope: !2, file: !2, line: 47, baseType: !22, size: 16, align: 16, offset: 336, flags: DIFlagPublic)
!46 = !DIDerivedType(tag: DW_TAG_member, name: "Status", scope: !2, file: !2, line: 50, baseType: !4, size: 8, align: 8, offset: 352, flags: DIFlagPublic)
!47 = !{i32 2, !"Dwarf Version", i32 5}
!48 = !{i32 2, !"Debug Info Version", i32 3}
!49 = distinct !DICompileUnit(language: DW_LANG_C, file: !2, producer: "RuSTy Structured text Compiler", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, globals: !50, splitDebugInlining: false)
!50 = !{!0, !5, !7, !9, !11, !13}
!51 = distinct !DISubprogram(name: "PumpController", linkageName: "PumpController", scope: !2, file: !2, line: 32, type: !52, scopeLine: 53, flags: DIFlagPublic, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !49, retainedNodes: !54)
!52 = !DISubroutineType(flags: DIFlagPublic, types: !53)
!53 = !{null, !25, !18, !18, !18, !22, !22, !4}
!54 = !{}
!55 = !DILocalVariable(name: "PumpController", scope: !51, file: !2, line: 53, type: !25)
!56 = !DILocation(line: 53, scope: !51)
!57 = !DILocation(line: 55, column: 5, scope: !51)
!58 = !DILocation(line: 58, column: 12, scope: !51)
!59 = !DILocation(line: 0, scope: !51)
!60 = !DILocation(line: 67, column: 11, scope: !51)
!61 = !DILocation(line: 79, column: 8, scope: !51)
!62 = !DILocation(line: 81, column: 11, scope: !51)
!63 = !DILocation(line: 91, column: 11, scope: !51)
!64 = !DILocation(line: 126, column: 11, scope: !51)
!65 = !DILocation(line: 133, scope: !51)
!66 = !DILocation(line: 135, scope: !51)
!67 = !DILocation(line: 137, scope: !51)
!68 = !DILocation(line: 61, column: 8, scope: !51)
!69 = !DILocation(line: 62, column: 8, scope: !51)
!70 = !DILocation(line: 63, column: 8, scope: !51)
!71 = !DILocation(line: 64, column: 8, scope: !51)
!72 = !DILocation(line: 59, column: 12, scope: !51)
!73 = !DILocation(line: 68, column: 12, scope: !51)
!74 = !DILocation(line: 69, column: 12, scope: !51)
!75 = !DILocation(line: 70, column: 12, scope: !51)
!76 = !DILocation(line: 71, column: 8, scope: !51)
!77 = !DILocation(line: 73, column: 11, scope: !51)
!78 = !DILocation(line: 74, column: 12, scope: !51)
!79 = !DILocation(line: 75, column: 12, scope: !51)
!80 = !DILocation(line: 76, column: 8, scope: !51)
!81 = !DILocation(line: 82, column: 12, scope: !51)
!82 = !DILocation(line: 83, column: 12, scope: !51)
!83 = !DILocation(line: 84, column: 12, scope: !51)
!84 = !DILocation(line: 85, column: 12, scope: !51)
!85 = !DILocation(line: 88, column: 8, scope: !51)
!86 = !DILocation(line: 86, column: 14, scope: !51)
!87 = !DILocation(line: 87, column: 12, scope: !51)
!88 = !DILocation(line: 92, column: 12, scope: !51)
!89 = !DILocation(line: 93, column: 8, scope: !51)
!90 = !DILocation(line: 95, column: 11, scope: !51)
!91 = !DILocation(line: 96, column: 12, scope: !51)
!92 = !DILocation(line: 97, column: 8, scope: !51)
!93 = !DILocation(line: 99, column: 11, scope: !51)
!94 = !DILocation(line: 100, column: 12, scope: !51)
!95 = !DILocation(line: 101, column: 8, scope: !51)
!96 = !DILocation(line: 103, column: 11, scope: !51)
!97 = !DILocation(line: 104, column: 12, scope: !51)
!98 = !DILocation(line: 105, column: 8, scope: !51)
!99 = !DILocation(line: 110, column: 11, scope: !51)
!100 = !DILocation(line: 111, column: 12, scope: !51)
!101 = !DILocation(line: 112, column: 8, scope: !51)
!102 = !DILocation(line: 114, column: 11, scope: !51)
!103 = !DILocation(line: 115, column: 12, scope: !51)
!104 = !DILocation(line: 116, column: 12, scope: !51)
!105 = !DILocation(line: 117, column: 12, scope: !51)
!106 = !DILocation(line: 118, column: 12, scope: !51)
!107 = !DILocation(line: 119, column: 8, scope: !51)
!108 = !DILocation(line: 121, column: 11, scope: !51)
!109 = !DILocation(line: 122, column: 12, scope: !51)
!110 = !DILocation(line: 123, column: 8, scope: !51)
!111 = !DILocation(line: 127, column: 12, scope: !51)
!112 = !DILocation(line: 128, column: 12, scope: !51)
!113 = !DILocation(line: 129, column: 12, scope: !51)
!114 = !DILocation(line: 130, column: 12, scope: !51)
!115 = !DILocation(line: 131, column: 8, scope: !51)
!116 = distinct !DISubprogram(name: "PLC_PRG", linkageName: "PLC_PRG", scope: !2, file: !2, line: 9, type: !117, scopeLine: 21, flags: DIFlagPublic, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !49, retainedNodes: !54)
!117 = !DISubroutineType(flags: DIFlagPublic, types: !118)
!118 = !{null, !15, !18, !18, !18, !22, !22}
!119 = !DILocalVariable(name: "PLC_PRG", scope: !116, file: !2, line: 21, type: !15)
!120 = !DILocation(line: 21, scope: !116)
!121 = !DILocation(line: 29, scope: !116)
