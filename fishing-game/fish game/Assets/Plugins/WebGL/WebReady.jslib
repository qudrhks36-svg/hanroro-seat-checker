// 게임이 몇 프레임 그려졌을 때 웹 페이지에 알려서, 불러오는 화면을 그때 걷는다(까만 첫 화면이 보이지 않게).
mergeInto(LibraryManager.library, {
  FG_Ready: function () { if (window.fgGameReady) window.fgGameReady(); }
});
