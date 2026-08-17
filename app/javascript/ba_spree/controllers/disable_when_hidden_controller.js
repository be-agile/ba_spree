import { Controller } from "@hotwired/stimulus"

// 非表示(hidden クラス等で display:none)になっている間、配下の入力欄を disabled にする。
//
// 目的: チェックアウトの payment 画面では、請求先住所(bill_address)フォームが
// 「配送先と同じ(use_shipping)」のとき hidden クラスで隠されるが、中の
// firstname_kana / lastname_kana などには required が付いたまま残る。
// この状態で「保存して続ける」を押すと、ブラウザの HTML5 バリデーションが
// 空の required フィールドを検証しようとし、対象が非表示で focus できないため
//   "An invalid form control ... is not focusable"
// を出して submit を完全に中止する(POST が一切飛ばない)。
//
// 非表示の input を disabled にすると、HTML5 バリデーションの対象から外れ、
// かつフォーム送信にも含まれなくなるため、この問題を回避できる。
// 表示に戻った際は disabled を解除し、required 等の挙動を元通りにする。
// @see https://github.com/be-agile/giga-repeat/issues/1210
export default class extends Controller {
  connect() {
    this.observer = new MutationObserver(() => this.sync())
    this.observer.observe(this.element, {
      attributes: true,
      attributeFilter: ["class", "style"]
    })
    this.sync()
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
      this.observer = null
    }
    // コントローラ離脱時に disabled を残さない(送信から欠落させない)
    this.enableControls()
  }

  sync() {
    if (this.isHidden()) {
      this.disableControls()
    } else {
      this.enableControls()
    }
  }

  // offsetParent が null = display:none(hidden クラス含む)で実際に非表示
  isHidden() {
    return this.element.offsetParent === null
  }

  disableControls() {
    this.controls().forEach((el) => {
      if (!el.disabled) {
        el.dataset.disabledByHidden = "true"
        el.disabled = true
      }
    })
  }

  enableControls() {
    this.controls().forEach((el) => {
      if (el.dataset.disabledByHidden === "true") {
        el.disabled = false
        delete el.dataset.disabledByHidden
      }
    })
  }

  controls() {
    return this.element.querySelectorAll("input, select, textarea")
  }
}
