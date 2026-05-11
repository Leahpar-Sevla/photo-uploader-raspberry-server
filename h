warning: in the working copy of 'README.md', LF will be replaced by CRLF the next time Git touches it
[1mdiff --git a/README.md b/README.md[m
[1mindex 80c0cd4..f1c3299 100644[m
[1m--- a/README.md[m
[1m+++ b/README.md[m
[36m@@ -1,5 +1,11 @@[m
 # Photo Uploader Raspberry + Linux Server[m
 [m
[32m+[m[32m![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25)[m
[32m+[m[32m![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-Photo%20Uploader-C51A4A)[m
[32m+[m[32m![Linux Server](https://img.shields.io/badge/Linux%20Server-SSH%2Frsync-0078D6)[m
[32m+[m[32m![License](https://img.shields.io/badge/License-MIT-blue)[m
[32m+[m
[32m+[m
 Reference project for importing photos from cameras connected to Raspberry Pi devices and centralizing them on an existing Linux server.[m
 [m
 The architecture is intentionally simple and operational:[m
[36m@@ -31,6 +37,13 @@[m [mThe Raspberry does not actively push files to the server.[m
 [m
 This keeps the Raspberry lightweight and lets the server centralize storage, logs, Samba, and backup.[m
 [m
[32m+[m[32m## Use cases[m
[32m+[m
[32m+[m[32m- Photo booths[m
[32m+[m[32m- Event photo workflows[m
[32m+[m[32m- Local retail/PDV photo operations[m
[32m+[m[32m- Camera-to-server automation[m
[32m+[m[32m- Raspberry Pi field collectors[m
 ## What this project includes[m
 [m
 ```text[m
