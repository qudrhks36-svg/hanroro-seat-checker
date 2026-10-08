import { toBlob, toPng } from 'html-to-image'

const render = (node: HTMLElement) => toPng(node, { pixelRatio: 2, cacheBust: true })

export async function savePng(node: HTMLElement): Promise<void> {
  const a = document.createElement('a')
  a.href = await render(node)
  a.download = 'saju.png'
  a.click()
}

/** Web Share API(파일 공유)가 되면 공유, 아니면(또는 공유 실패 시) 저장으로 대체. 사용자 취소(AbortError)는 폴백 없이 종료 */
export async function sharePng(node: HTMLElement): Promise<void> {
  const blob = await toBlob(node, { pixelRatio: 2, cacheBust: true })
  if (!blob) throw new Error('toBlob failed')
  const file = new File([blob], 'saju.png', { type: 'image/png' })
  if (navigator.canShare?.({ files: [file] })) {
    try {
      await navigator.share({ files: [file], title: '내 사주 결과' })
      return
    } catch (e) {
      if ((e as Error).name === 'AbortError') return
    }
  }
  await savePng(node)
}
