#Requires AutoHotkey v2.0

class TestClass {
    static Active := false
    static IsActive() {
        return this.Active
    }
    static OnClick() {
        FileAppend("Clicked while active`n", "*")
    }
}

#HotIf TestClass.IsActive()
~LButton::TestClass.OnClick()
#HotIf

TestClass.Active := true
ExitApp()
