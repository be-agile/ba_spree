import { Controller } from "@hotwired/stimulus"
import { easepick } from '@easepick/core';
import { RangePlugin } from '@easepick/range-plugin';
import { PresetPlugin } from '@easepick/preset-plugin';

export default class extends Controller {
  static targets = [ "picker", "dateFrom", "dateTo", "label" ]
  connect() {
    this.picker = new easepick.create({
      element: this.pickerTarget,
      lang: 'ja-JP',
      inline: true,
      css: [
        'https://cdn.jsdelivr.net/npm/@easepick/core@1.2.0/dist/index.css',
        'https://cdn.jsdelivr.net/npm/@easepick/range-plugin@1.2.0/dist/index.css',
        'https://cdn.jsdelivr.net/npm/@easepick/preset-plugin@1.2.0/dist/index.css',
      ],
      doc: document,
      plugins: [RangePlugin, PresetPlugin],
      RangePlugin: {
        tooltip: true,
        locale: {
          one: '日',
          other: '日間'
        },
        startDate: this.dateFromTarget.value,
        endDate: this.dateToTarget.value,
      },
      PresetPlugin: {
        customLabels: [
          '今日',
          '昨日',
          '直近7日間',
          '直近30日間',
          '今月',
          '先月'
        ],
        position: 'left'
      }
    })

    this.picker.on('render', () => {
      this.picker.ui.container.style.boxShadow = 'none';
    });

    this.picker.on('select', (event) => {
      const data = event.detail;
      this.dateFromTarget.value = data.start
      this.dateToTarget.value = data.end

      // https://stackoverflow.com/questions/68624668/how-can-i-submit-a-form-on-input-change-with-turbo-streams
      this.pickerTarget.closest('form').requestSubmit()

      this.labelTarget.innerHTML = this.pickerTarget.innerHTML
    })
  }

  open() {
    this.picker.show()
  }
}
