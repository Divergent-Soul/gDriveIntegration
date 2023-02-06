public class MIMEHelper {
    public static Map<String, String> mimeTypes = new Map<String, String> {
        '.pdf' => 'application/pdf',
        '.doc' => 'application/msword',
        '.docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        '.word_x' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        '.xls' => 'application/vnd.ms-excel',
        '.xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        '.ppt' => 'application/vnd.ms-powerpoint',
        '.pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        '.jpeg' => 'image/jpeg',
        '.jpg' => 'image/jpeg',
        '.png' => 'image/png',
        '.gif' => 'image/gif',
        '.zip' => 'application/zip',
        '.rar' => 'application/x-rar-compressed',
        '.txt' => 'text/plain',
        '.html' => 'text/html',
        '.csv' => 'text/csv',
        '.mp3' => 'audio/mpeg',
        '.mp4' => 'video/mp4',
        '.ogg' => 'audio/ogg',
        '.ogv' => 'video/ogg',
        '.mov' => 'video/quicktime',
        '.avi' => 'video/x-msvideo',
        '.wmv' => 'video/x-ms-wmv',
        '.text' => 'text/plain',
        '.excel_x' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        '.json' => 'application/vnd.google-apps.script+json',
        '.xml' => 'text/xml'
    };

    public static String getMIMEType(String fileType) {
        return mimeTypes.get('.'+fileType.toLowerCase());
    }
}