trigger uploadFileToGdriveTriggerOnContentVersion on ContentVersion (after insert) {
    uploadFileToGdrive.fileUploadHandler(trigger.new);
}