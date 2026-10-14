// 사진 찍기(GDD 9번): 웹에서는 컴퓨터에 파일을 직접 못 쓰므로, 브라우저 다운로드로 PNG를 저장한다.
mergeInto(LibraryManager.library, {
  FG_DownloadPng: function (ptr, length, namePtr) {
    var bytes = HEAPU8.slice(ptr, ptr + length);
    var blob = new Blob([bytes], { type: 'image/png' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url; a.download = UTF8ToString(namePtr);
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
    setTimeout(function () { URL.revokeObjectURL(url); }, 5000);
  }
});
