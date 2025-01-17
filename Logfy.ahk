#Requires AutoHotkey v2.0

Class Logfy {
    Class Utils {
        static ValidateFilePath(path) {
            SplitPath(path, &fileName, &OutDir)
            try {
                if not DirExist(OutDir) {
                    DirCreate(OutDir)
                }
                return OutDir '\' fileName
            } catch Error as e {
                throw Error('Invalid log file path. ' e.Message)
            }
        }
        static SendNtfy(message, title, url, topic, priority) {
            args := 'curl -H "X-Priority: {5}" -H "X-Title: {2}" -d "{1}" {3}/{4} -s'
            args := Format(args, message, title, url, topic, priority)
            Run(args, , 'hide')
        }
        static WriteToFile(message, path) {
            script := A_ComSpec ' /c echo "{1}" >> "{2}"'
            script := Format(script, message, path)
            Run(script,, 'hide')
        }
    }
    static LogLevels := {
        DEBUG: {value: 1, name: 'DEBUG'},
        INFO: {value: 2, name: 'INFO'},
        WARN: {value: 3, name: 'WARN'},
        ERROR: {value: 4, name: 'ERROR'},
        FATAL: {value: 5, name: 'FATAL'}
    }
    static GlobalSelectedLogLevel := Logfy.LogLevels.DEBUG
    SelectedLogLevel := 0
    static GlobalLogFiles := [A_WorkingDir '\Logs\' A_ComputerName '\' A_Year '-' A_MM '-' A_DD '.txt']
    LogFiles := 0
    static GlobalNtfyUrl := ''
    NtfyUrl := 0
    static GlobalNtfyTopic := ''
    NtfyTopic := 0
    static GlobalNtfyTitle := ''
    NtfyTitle := 0
    static GlobalUseLogLevelAsNtfyPriority := true
    UseLogLevelAsNtfyPriority := 0
    static GlobalDefaultNtfyPriority := 3
    DefaultNtfyPriority := 0
    static GlobalMessagePlaceholder := '[ {{timestamp}} ] [ {{level}} ] -> {{message}}'
    MessagePlaceholder := 0
    static GlobalCustomPlaceholders := {}
    CustomPlaceholders := 0

    _FormatMessage(message, level) {
        msg := this.MessagePlaceholder ? this.MessagePlaceholder : Logfy.GlobalMessagePlaceholder
        msg := StrReplace(msg, '{{message}}', message)
        msg := StrReplace(msg, '{{level}}', level.name)
        msg := StrReplace(msg, '{{timestamp}}', FormatTime('yyyy-MM-dd-hh-mm-ss', A_Now))
        cp := this.CustomPlaceholders ? this.CustomPlaceholders : Logfy.GlobalCustomPlaceholders
        for prop, value in cp.OwnProps() {
            msg := StrReplace(msg, '{{' prop '}}', value)
        }
        return msg
    }
    _WriteEntry(message) {
        paths := this.LogFiles ? this.LogFiles : Logfy.GlobalLogFiles
        for i, p in paths {
            p := Logfy.Utils.ValidateFilePath(p)
            Logfy.Utils.WriteToFile(message, p)
        }
    }
    Log(message, level := Logfy.LogLevels.INFO) {
        selLogLevel := this.SelectedLogLevel ? this.SelectedLogLevel : Logfy.GlobalSelectedLogLevel
        if selLogLevel.value > level.value {
            return
        }

        msg := this._FormatMessage(message, level)
        try {
            this.LogNtfy(msg, level)
            this._WriteEntry(msg)
        } catch Error as e {
            FileAppend('Error logging: ' e.Message '`n', A_Temp '\' A_Now 'LogfyError.txt')
            this.LogNtfy('Error logging: ' e.Message, level)
        }
    }
    LogNtfy(message, level) {
        if this.NtfyUrl and This.NtfyTopic {
            logLevelPriority := this.UseLogLevelAsNtfyPriority ? this.UseLogLevelAsNtfyPriority : Logfy.GlobalUseLogLevelAsNtfyPriority
            if logLevelPriority {
                priority := level.value
            } else {
                priority := this.DefaultNtfyPriority ? this.DefaultNtfyPriority : Logfy.GlobalDefaultNtfyPriority
            }
            Logfy.Utils.SendNtfy( message, this.NtfyTitle, this.NtfyUrl, this.NtfyTopic, priority)
        }
    }

    Debug(msg) => this.Log(msg, Logfy.LogLevels.DEBUG)
    Info(msg) => this.Log(msg, Logfy.LogLevels.INFO)
    Warn(msg) => this.Log(msg, Logfy.LogLevels.WARN)
    Error(msg) => this.Log(msg, Logfy.LogLevels.ERROR)
    Fatal(msg) => this.Log(msg, Logfy.LogLevels.FATAL)
}