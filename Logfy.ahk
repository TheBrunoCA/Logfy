#Requires AutoHotkey v2.0

class Logfy {

    __New(_fileName, _customLogDir?, _logPruning := false, ntfyHost := '', ntfyChannels := []) {
        this.thisFileName := _fileName
        this.logFileDir := _customLogDir ?? Logfy._defaultLogDir
        this.ntfyHost := ntfyHost
        this.ntfyChannels := ntfyChannels
        this.setLogPruning(_logPruning)
    }

    static _logLevels := Map('DEBUG', 1, 'INFO', 2, 'WARN', 3, 'ERROR', 4, 'FATAL', 5)
    getLogLevels() => Logfy._logLevels
    static _selectedLogLevel := 'DEBUG'
    setSelectedLogLevel(level) {
        if !this.validateLogLevel(level)
            throw Error('Invalid log level')
        Logfy._selectedLogLevel := level
    }
    validateLogLevel(level) => Logfy._logLevels.Has(level)
    getSelectedLogLevel() => Logfy._selectedLogLevel

    static _defaultLogDir := A_WorkingDir '\Logs\'
    setDefaultLogDir(path) {
        if !this.validateLogDir(path)
            throw Error('Invalid log file path')
        Logfy._defaultLogDir := path
    }
    getDefaultLogDir() => Logfy._defaultLogDir
    validateLogDir(path) {
        SplitPath(path, , &OutDir)
        if !DirExist(OutDir) {
            try {
                DirCreate(OutDir)
            }
            catch as e {
                return false
            }
        }
        return true
    }

    static _messagePlaceholder := '[ {{timestamp}} ] | [ {{level}} ] | [ {{thisFileName}} ] -> {{message}}'
    setMessagePlaceholder(placeholder) => Logfy._messagePlaceholder := placeholder
    getMessagePlaceholder() => Logfy._messagePlaceholder

    static _customPlaceholders := Map()
    addCustomPlaceholder(placeholder, valueOrCallback) {
        if valueOrCallback is Func
            Logfy._customPlaceholders[placeholder] := valueOrCallback()
        else
            Logfy._customPlaceholders[placeholder] := valueOrCallback
    }
    getCustomPlaceholders() => Logfy._customPlaceholders

    _formatMessage(message, level) {
        msg := this.getMessagePlaceholder()
        msg := StrReplace(msg, '{{message}}', message)
        msg := StrReplace(msg, '{{level}}', level)
        msg := StrReplace(msg, '{{timestamp}}', FormatTime('yyyy-MM-dd-hh-mm-ss', A_Now))
        msg := StrReplace(msg, '{{thisFileName}}', this.thisFileName)
        for k, v in this.getCustomPlaceholders() {
            if v is Func
                msg := StrReplace(msg, '{{' k '}}', v.Call())
            else
                msg := StrReplace(msg, '{{' k '}}', v)
        }
        return msg
    }

    _getValidLogPath() {
        if SubStr(this.logFileDir, -1, 1) != '\'
            this.logFileDir .= '\'
        out := this.logFileDir A_YYYY '\' A_MM '\' A_DD '\' this.thisFileName '.txt'
        SplitPath(out,,&OutDir)
        if !DirExist(OutDir) {
            try {
                DirCreate(OutDir)
            }
            catch as e {
                return false
            }
        }
        return out
    }

    _write_log_entry(entry) {
        out := this._getValidLogPath()
        if !out
            return
        try {
            FileAppend(entry '`n', out, 'UTF-8')
        }
    }

    _sendToNtfy(message, level, channel) {
        if !this.ntfyHost {
            return
        }
        req := ComObject('WinHttp.WinHttpRequest.5.1')
        req.Open('POST', this.ntfyHost '/' channel, false)
        req.SetRequestHeader('Content-Type', 'application/json')
        req.SetRequestHeader('priority', this.getLogLevels()[level])
        req.SetRequestHeader('title', this.thisFileName ' - ' level)
        req.Send(message)
    }

    Log(message, level := 'INFO') {
        if !this.validateLogLevel(level)
            throw Error('Invalid log level')
        if this.getLogLevels()[level] < this.getLogLevels()[this.getSelectedLogLevel()]
            return
        formatedMessage := this._formatMessage(message, level)
        this._write_log_entry(formatedMessage)
        for channel in this.ntfyChannels {
            this._sendToNtfy(formatedMessage, level, channel)
        }
    }

    Debug(msg) => this.Log(msg, 'DEBUG')
    Info(msg) => this.Log(msg, 'INFO')
    Warn(msg) => this.Log(msg, 'WARN')
    Error(msg) => this.Log(msg, 'ERROR')
    Fatal(msg) => this.Log(msg, 'FATAL')

    static _isLogPruningEnabled := false
    static _isTimerAlreadySet := false
    setLogPruning(enabled := true) {
        SetTimer(this._pruneLogs.Bind(this), this.getLogPruningInterval() * (enabled and not Logfy._isTimerAlreadySet))
        Logfy._isTimerAlreadySet := enabled
        Logfy._isLogPruningEnabled := enabled
    }
    getLogPruning() => Logfy._isLogPruningEnabled

    static _logPruningInterval := 1000*60*5
    setLogPruningInterval(interval := 1000*60*5) => Logfy._logPruningInterval := interval
    getLogPruningInterval() => Logfy._logPruningInterval

    static _maxLogSizeInMB := 0
    setMaxLogSizeInMB(sizeInMB := 0) => Logfy._maxLogSizeInMB := sizeInMB
    getMaxLogSizeInMB() => Logfy._maxLogSizeInMB

    static _maxLogAgeInDays := 0
    setMaxLogAgeInDays(ageInDays := 0) => Logfy._maxLogAgeInDays := ageInDays
    getMaxLogAgeInDays() => Logfy._maxLogAgeInDays

    _pruneLogs(*) {
        if !this.getLogPruning()
            return
        if !this.getMaxLogSizeInMB() and !this.getMaxLogAgeInDays()
            return
        loop files this.logFileDir, 'FR' {
            if this.getMaxLogSizeInMB() and FileGetSize(A_LoopFileFullPath, 'M') > this.getMaxLogSizeInMB() {
                try {
                    FileDelete(A_LoopFileFullPath)
                }
                catch as e {
                    this.Error('Failed to prune log file: ' . A_LoopFileFullPath . ' (' . e.Message . ')')
                }
            }
            if this.getMaxLogAgeInDays() and A_Now > DateAdd(FileGetTime(A_LoopFileFullPath, 'C'), this.getMaxLogAgeInDays(), 'D') {
                try {
                    FileDelete(A_LoopFileFullPath)
                }
                catch as e {
                    this.Error('Failed to prune log file: ' . A_LoopFileFullPath . ' (' . e.Message . ')')
                }
            }
        }
    }
}