package com.jnesis.capacitor.brightcoveplayer.exception

open class PluginException(errorCode: ErrorCode) : Exception(errorCode.name) {

    enum class ErrorCode {
        NOT_IMPLEMENTED,
        MISSING_POLICYKEY,
        MISSING_ACCOUNTID,
        MISSING_FILEID,
        MISSING_SOURCE_URL,
        MEDIA_NOT_FOUND,
        FILE_NOT_EXIST_AND_NO_INTERNET,
        NO_INTERNET_CONNECTION,
        UNKNOWN_REASON,
        TECHNICAL_ERROR
    }
}
