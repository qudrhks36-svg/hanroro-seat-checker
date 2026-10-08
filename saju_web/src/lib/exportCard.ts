import { toPng } from 'html-to-image'

const render = (node: HTMLElement) => toPng(node, { pixelRatio: 2, cacheBust: true })

export async function savePng(node: HTMLElement): Promise<void> {
  const a = document.createElement('a')
  a.href = await render(node)
  a.download = 'saju.png'
  a.click()
}

/** Web Share API(파일 공유)가 되면 공유, 아니면 저장으로 대체 */
export async function sharePng(node: HTMLElement): Promise<void> {
  const blob = await (await fetch(await render(node))).blob()
  const file = new File([blob], 'saju.png', { type: 'image/png' })
  if (navigator.canShare?.({ files: [file] })) await navigator.share({ files: [file], title: '내 사주 결과' })
  else await savePng(node)
}
