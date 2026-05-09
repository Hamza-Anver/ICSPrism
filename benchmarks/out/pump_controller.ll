; ModuleID = '/tmp/.tmpfz3aqo/benchmarks/pump_controller.st.ll'
source_filename = "/workspaces/ICSPrism/benchmarks/pump_controller.st"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%__vtable_PumpController = type { ptr }
%PLC_PRG = type { i8, i8, i8, i16, i16, %PumpController }
%PumpController = type { ptr, i8, i8, i8, i16, i16, i8, i16, i16, i16, i16, [8 x i16], i16, i8 }

@MODE_INIT = unnamed_addr constant i8 0
@MODE_IDLE = unnamed_addr constant i8 1
@MODE_ARMED = unnamed_addr constant i8 2
@MODE_RUN = unnamed_addr constant i8 3
@MODE_FAULT = unnamed_addr constant i8 4
@__vtable_PumpController_instance = global %__vtable_PumpController zeroinitializer
@PLC_PRG_instance = global %PLC_PRG zeroinitializer
@llvm.global_ctors = appending global [1 x { i32, ptr, ptr }] [{ i32, ptr, ptr } { i32 65535, ptr @__unit_pump_controller_st__ctor, ptr null }]

define void @PumpController(ptr %0) {
entry:
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
  %load_CycleCount = load i16, ptr %CycleCount, align 2
  %1 = sext i16 %load_CycleCount to i32
  %tmpVar = add i32 %1, 1
  %2 = trunc i32 %tmpVar to i16
  store i16 %2, ptr %CycleCount, align 2
  %load_Mode = load i8, ptr %Mode, align 1
  %ran_once_0 = alloca i8, align 1
  %is_incrementing_0 = alloca i8, align 1
  switch i8 %load_Mode, label %else [
    i8 0, label %case
    i8 1, label %case20
    i8 2, label %case25
    i8 3, label %case35
    i8 4, label %case78
  ]

case:                                             ; preds = %entry
  store i8 0, ptr %ran_once_0, align 1
  store i8 0, ptr %is_incrementing_0, align 1
  store i16 0, ptr %i, align 2
  store i8 1, ptr %is_incrementing_0, align 1
  br label %while_body

case20:                                           ; preds = %entry
  %load_CmdReset = load i8, ptr %CmdReset, align 1
  %3 = icmp ne i8 %load_CmdReset, 0
  br i1 %3, label %condition_body22, label %continue21

case25:                                           ; preds = %entry
  %load_ArmedCycles = load i16, ptr %ArmedCycles, align 2
  %4 = sext i16 %load_ArmedCycles to i32
  %tmpVar26 = add i32 %4, 1
  %5 = trunc i32 %tmpVar26 to i16
  store i16 %5, ptr %ArmedCycles, align 2
  %load_CmdReset29 = load i8, ptr %CmdReset, align 1
  %6 = icmp ne i8 %load_CmdReset29, 0
  br i1 %6, label %condition_body30, label %else27

case35:                                           ; preds = %entry
  %load_Pressure = load i16, ptr %Pressure, align 2
  %7 = sext i16 %load_Pressure to i32
  %tmpVar37 = icmp sgt i32 %7, 70
  %8 = zext i1 %tmpVar37 to i8
  %9 = icmp ne i8 %8, 0
  br i1 %9, label %condition_body38, label %continue36

case78:                                           ; preds = %entry
  %load_CmdReset80 = load i8, ptr %CmdReset, align 1
  %10 = icmp ne i8 %load_CmdReset80, 0
  br i1 %10, label %condition_body81, label %continue79

else:                                             ; preds = %entry
  br label %continue

continue:                                         ; preds = %continue79, %continue74, %continue28, %continue23, %continue1, %else
  %load_Mode82 = load i8, ptr %Mode, align 1
  store i8 %load_Mode82, ptr %Status, align 1
  ret void

while_body:                                       ; preds = %continue5, %case
  %load_ran_once_0 = load i8, ptr %ran_once_0, align 1
  %11 = icmp ne i8 %load_ran_once_0, 0
  br i1 %11, label %condition_body, label %continue2

continue1:                                        ; preds = %condition_body14, %condition_body10
  store i16 0, ptr %PressureScore, align 2
  store i16 0, ptr %ArmedCycles, align 2
  store i16 0, ptr %Offset, align 2
  store i8 1, ptr %Mode, align 1
  br label %continue

condition_body:                                   ; preds = %while_body
  %load_i = load i16, ptr %i, align 2
  %12 = sext i16 %load_i to i32
  %tmpVar3 = add i32 %12, 1
  %13 = trunc i32 %tmpVar3 to i16
  store i16 %13, ptr %i, align 2
  br label %continue2

continue2:                                        ; preds = %condition_body, %while_body
  store i8 1, ptr %ran_once_0, align 1
  %load_is_incrementing_0 = load i8, ptr %is_incrementing_0, align 1
  %14 = icmp ne i8 %load_is_incrementing_0, 0
  br i1 %14, label %condition_body6, label %else4

condition_body6:                                  ; preds = %continue2
  %load_i8 = load i16, ptr %i, align 2
  %15 = sext i16 %load_i8 to i32
  %tmpVar9 = icmp sgt i32 %15, 7
  %16 = zext i1 %tmpVar9 to i8
  %17 = icmp ne i8 %16, 0
  br i1 %17, label %condition_body10, label %continue7

else4:                                            ; preds = %continue2
  %load_i12 = load i16, ptr %i, align 2
  %18 = sext i16 %load_i12 to i32
  %tmpVar13 = icmp slt i32 %18, 7
  %19 = zext i1 %tmpVar13 to i8
  %20 = icmp ne i8 %19, 0
  br i1 %20, label %condition_body14, label %continue11

continue5:                                        ; preds = %continue11, %continue7
  %load_i16 = load i16, ptr %i, align 2
  %21 = sext i16 %load_i16 to i32
  %tmpVar17 = mul i32 1, %21
  %tmpVar18 = add i32 %tmpVar17, 0
  %tmpVar19 = getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 %tmpVar18
  store i16 0, ptr %tmpVar19, align 2
  br label %while_body

condition_body10:                                 ; preds = %condition_body6
  br label %continue1

buffer_block:                                     ; No predecessors!
  br label %continue7

continue7:                                        ; preds = %buffer_block, %condition_body6
  br label %continue5

condition_body14:                                 ; preds = %else4
  br label %continue1

buffer_block15:                                   ; No predecessors!
  br label %continue11

continue11:                                       ; preds = %buffer_block15, %else4
  br label %continue5

condition_body22:                                 ; preds = %case20
  store i16 0, ptr %PressureScore, align 2
  store i16 0, ptr %ArmedCycles, align 2
  store i16 0, ptr %Offset, align 2
  br label %continue21

continue21:                                       ; preds = %condition_body22, %case20
  %load_CmdArm = load i8, ptr %CmdArm, align 1
  %22 = icmp ne i8 %load_CmdArm, 0
  br i1 %22, label %condition_body24, label %continue23

condition_body24:                                 ; preds = %continue21
  store i8 2, ptr %Mode, align 1
  store i16 0, ptr %ArmedCycles, align 2
  br label %continue23

continue23:                                       ; preds = %condition_body24, %continue21
  br label %continue

condition_body30:                                 ; preds = %case25
  store i8 1, ptr %Mode, align 1
  store i16 0, ptr %PressureScore, align 2
  store i16 0, ptr %ArmedCycles, align 2
  store i16 0, ptr %Offset, align 2
  br label %continue28

else27:                                           ; preds = %case25
  %load_CmdStart = load i8, ptr %CmdStart, align 1
  %23 = icmp ne i8 %load_CmdStart, 0
  %load_ArmedCycles32 = load i16, ptr %ArmedCycles, align 2
  %24 = sext i16 %load_ArmedCycles32 to i32
  %tmpVar33 = icmp sge i32 %24, 3
  %25 = zext i1 %tmpVar33 to i8
  %26 = icmp ne i8 %25, 0
  %27 = and i1 %23, %26
  %28 = zext i1 %27 to i8
  %29 = icmp ne i8 %28, 0
  br i1 %29, label %condition_body34, label %continue31

continue28:                                       ; preds = %continue31, %condition_body30
  br label %continue

condition_body34:                                 ; preds = %else27
  store i8 3, ptr %Mode, align 1
  br label %continue31

continue31:                                       ; preds = %condition_body34, %else27
  br label %continue28

condition_body38:                                 ; preds = %case35
  %load_PressureScore = load i16, ptr %PressureScore, align 2
  %30 = sext i16 %load_PressureScore to i32
  %tmpVar39 = add i32 %30, 1
  %31 = trunc i32 %tmpVar39 to i16
  store i16 %31, ptr %PressureScore, align 2
  br label %continue36

continue36:                                       ; preds = %condition_body38, %case35
  %load_Temp = load i16, ptr %Temp, align 2
  %32 = sext i16 %load_Temp to i32
  %tmpVar41 = icmp sgt i32 %32, 50
  %33 = zext i1 %tmpVar41 to i8
  %34 = icmp ne i8 %33, 0
  %load_Temp42 = load i16, ptr %Temp, align 2
  %35 = sext i16 %load_Temp42 to i32
  %tmpVar43 = icmp slt i32 %35, 60
  %36 = zext i1 %tmpVar43 to i8
  %37 = icmp ne i8 %36, 0
  %38 = and i1 %34, %37
  %39 = zext i1 %38 to i8
  %40 = icmp ne i8 %39, 0
  br i1 %40, label %condition_body44, label %continue40

condition_body44:                                 ; preds = %continue36
  %load_Offset = load i16, ptr %Offset, align 2
  %41 = sext i16 %load_Offset to i32
  %tmpVar45 = add i32 %41, 1
  %42 = trunc i32 %tmpVar45 to i16
  store i16 %42, ptr %Offset, align 2
  br label %continue40

continue40:                                       ; preds = %condition_body44, %continue36
  %load_PressureScore47 = load i16, ptr %PressureScore, align 2
  %43 = sext i16 %load_PressureScore47 to i32
  %tmpVar48 = icmp sge i32 %43, 4
  %44 = zext i1 %tmpVar48 to i8
  %45 = icmp ne i8 %44, 0
  br i1 %45, label %condition_body49, label %continue46

condition_body49:                                 ; preds = %continue40
  %tmpVar50 = getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 0
  %tmpVar51 = getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 0
  %load_tmpVar = load i16, ptr %tmpVar51, align 2
  %46 = sext i16 %load_tmpVar to i32
  %tmpVar52 = add i32 %46, 1
  %47 = trunc i32 %tmpVar52 to i16
  store i16 %47, ptr %tmpVar50, align 2
  br label %continue46

continue46:                                       ; preds = %condition_body49, %continue40
  %tmpVar54 = getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 0
  %load_tmpVar55 = load i16, ptr %tmpVar54, align 2
  %48 = sext i16 %load_tmpVar55 to i32
  %tmpVar56 = icmp sgt i32 %48, 2
  %49 = zext i1 %tmpVar56 to i8
  %50 = icmp ne i8 %49, 0
  br i1 %50, label %condition_body57, label %continue53

condition_body57:                                 ; preds = %continue46
  %tmpVar58 = getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 1
  %tmpVar59 = getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 1
  %load_tmpVar60 = load i16, ptr %tmpVar59, align 2
  %51 = sext i16 %load_tmpVar60 to i32
  %tmpVar61 = add i32 %51, 1
  %52 = trunc i32 %tmpVar61 to i16
  store i16 %52, ptr %tmpVar58, align 2
  br label %continue53

continue53:                                       ; preds = %condition_body57, %continue46
  %tmpVar63 = getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 1
  %load_tmpVar64 = load i16, ptr %tmpVar63, align 2
  %53 = sext i16 %load_tmpVar64 to i32
  %tmpVar65 = icmp sgt i32 %53, 1
  %54 = zext i1 %tmpVar65 to i8
  %55 = icmp ne i8 %54, 0
  br i1 %55, label %condition_body66, label %continue62

condition_body66:                                 ; preds = %continue53
  %load_Offset67 = load i16, ptr %Offset, align 2
  %56 = sext i16 %load_Offset67 to i32
  %tmpVar68 = mul i32 1, %56
  %tmpVar69 = add i32 %tmpVar68, 0
  %tmpVar70 = getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 %tmpVar69
  store i16 1234, ptr %tmpVar70, align 2
  br label %continue62

continue62:                                       ; preds = %condition_body66, %continue53
  %load_CmdReset72 = load i8, ptr %CmdReset, align 1
  %57 = icmp ne i8 %load_CmdReset72, 0
  br i1 %57, label %condition_body73, label %continue71

condition_body73:                                 ; preds = %continue62
  store i8 1, ptr %Mode, align 1
  store i16 0, ptr %PressureScore, align 2
  store i16 0, ptr %ArmedCycles, align 2
  store i16 0, ptr %Offset, align 2
  br label %continue71

continue71:                                       ; preds = %condition_body73, %continue62
  %load_Temp75 = load i16, ptr %Temp, align 2
  %58 = sext i16 %load_Temp75 to i32
  %tmpVar76 = icmp sgt i32 %58, 90
  %59 = zext i1 %tmpVar76 to i8
  %60 = icmp ne i8 %59, 0
  br i1 %60, label %condition_body77, label %continue74

condition_body77:                                 ; preds = %continue71
  store i8 4, ptr %Mode, align 1
  br label %continue74

continue74:                                       ; preds = %condition_body77, %continue71
  br label %continue

condition_body81:                                 ; preds = %case78
  store i8 1, ptr %Mode, align 1
  store i16 0, ptr %PressureScore, align 2
  store i16 0, ptr %ArmedCycles, align 2
  store i16 0, ptr %Offset, align 2
  br label %continue79

continue79:                                       ; preds = %condition_body81, %case78
  br label %continue
}

define void @PLC_PRG(ptr %0) {
entry:
  %CmdArm = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 0
  %CmdStart = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 1
  %CmdReset = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 2
  %Pressure = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 3
  %Temp = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 4
  %Controller = getelementptr inbounds nuw %PLC_PRG, ptr %0, i32 0, i32 5
  %1 = getelementptr inbounds %PumpController, ptr %Controller, i32 0, i32 1
  %load_CmdArm = load i8, ptr %CmdArm, align 1
  store i8 %load_CmdArm, ptr %1, align 1
  %2 = getelementptr inbounds %PumpController, ptr %Controller, i32 0, i32 2
  %load_CmdStart = load i8, ptr %CmdStart, align 1
  store i8 %load_CmdStart, ptr %2, align 1
  %3 = getelementptr inbounds %PumpController, ptr %Controller, i32 0, i32 3
  %load_CmdReset = load i8, ptr %CmdReset, align 1
  store i8 %load_CmdReset, ptr %3, align 1
  %4 = getelementptr inbounds %PumpController, ptr %Controller, i32 0, i32 4
  %load_Pressure = load i16, ptr %Pressure, align 2
  store i16 %load_Pressure, ptr %4, align 2
  %5 = getelementptr inbounds %PumpController, ptr %Controller, i32 0, i32 5
  %load_Temp = load i16, ptr %Temp, align 2
  store i16 %load_Temp, ptr %5, align 2
  call void @PumpController(ptr %Controller)
  ret void
}

define void @PLC_PRG__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8
  store ptr %0, ptr %self, align 8
  %deref = load ptr, ptr %self, align 8
  %CmdArm = getelementptr inbounds nuw %PLC_PRG, ptr %deref, i32 0, i32 0
  store i8 0, ptr %CmdArm, align 1
  %deref1 = load ptr, ptr %self, align 8
  %CmdStart = getelementptr inbounds nuw %PLC_PRG, ptr %deref1, i32 0, i32 1
  store i8 0, ptr %CmdStart, align 1
  %deref2 = load ptr, ptr %self, align 8
  %CmdReset = getelementptr inbounds nuw %PLC_PRG, ptr %deref2, i32 0, i32 2
  store i8 0, ptr %CmdReset, align 1
  %deref3 = load ptr, ptr %self, align 8
  %Pressure = getelementptr inbounds nuw %PLC_PRG, ptr %deref3, i32 0, i32 3
  store i16 0, ptr %Pressure, align 2
  %deref4 = load ptr, ptr %self, align 8
  %Temp = getelementptr inbounds nuw %PLC_PRG, ptr %deref4, i32 0, i32 4
  store i16 0, ptr %Temp, align 2
  %deref5 = load ptr, ptr %self, align 8
  %Controller = getelementptr inbounds nuw %PLC_PRG, ptr %deref5, i32 0, i32 5
  call void @PumpController__ctor(ptr %Controller)
  ret void
}

define void @PumpController__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8
  store ptr %0, ptr %self, align 8
  %deref = load ptr, ptr %self, align 8
  %__vtable = getelementptr inbounds nuw %PumpController, ptr %deref, i32 0, i32 0
  call void @__PumpController___vtable__ctor(ptr %__vtable)
  %deref1 = load ptr, ptr %self, align 8
  %Mode = getelementptr inbounds nuw %PumpController, ptr %deref1, i32 0, i32 6
  store i8 0, ptr %Mode, align 1
  %deref2 = load ptr, ptr %self, align 8
  %CycleCount = getelementptr inbounds nuw %PumpController, ptr %deref2, i32 0, i32 7
  store i16 0, ptr %CycleCount, align 2
  %deref3 = load ptr, ptr %self, align 8
  %PressureScore = getelementptr inbounds nuw %PumpController, ptr %deref3, i32 0, i32 8
  store i16 0, ptr %PressureScore, align 2
  %deref4 = load ptr, ptr %self, align 8
  %ArmedCycles = getelementptr inbounds nuw %PumpController, ptr %deref4, i32 0, i32 9
  store i16 0, ptr %ArmedCycles, align 2
  %deref5 = load ptr, ptr %self, align 8
  %Offset = getelementptr inbounds nuw %PumpController, ptr %deref5, i32 0, i32 10
  store i16 0, ptr %Offset, align 2
  %deref6 = load ptr, ptr %self, align 8
  %Buffer = getelementptr inbounds nuw %PumpController, ptr %deref6, i32 0, i32 11
  call void @__PumpController_Buffer__ctor(ptr %Buffer)
  %deref7 = load ptr, ptr %self, align 8
  %__vtable8 = getelementptr inbounds nuw %PumpController, ptr %deref7, i32 0, i32 0
  store ptr @__vtable_PumpController_instance, ptr %__vtable8, align 8
  ret void
}

define void @__PumpController_Buffer__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8
  store ptr %0, ptr %self, align 8
  ret void
}

define void @__vtable_PumpController__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8
  store ptr %0, ptr %self, align 8
  %deref = load ptr, ptr %self, align 8
  %__body = getelementptr inbounds nuw %__vtable_PumpController, ptr %deref, i32 0, i32 0
  call void @____vtable_PumpController___body__ctor(ptr %__body)
  %deref1 = load ptr, ptr %self, align 8
  %__body2 = getelementptr inbounds nuw %__vtable_PumpController, ptr %deref1, i32 0, i32 0
  store ptr @PumpController, ptr %__body2, align 8
  ret void
}

define void @__PumpController___vtable__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8
  store ptr %0, ptr %self, align 8
  ret void
}

define void @____vtable_PumpController___body__ctor(ptr %0) {
entry:
  %self = alloca ptr, align 8
  store ptr %0, ptr %self, align 8
  ret void
}

define void @__unit_pump_controller_st__ctor() {
entry:
  call void @__vtable_PumpController__ctor(ptr @__vtable_PumpController_instance)
  call void @PLC_PRG__ctor(ptr @PLC_PRG_instance)
  ret void
}
