import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "container",
    "filtersContainer",
    "groupsContainer",
    "hiddenInput",
    "filterTemplate",
    "groupTemplate",
    "combinatorButton",
    "combinatorLabel",
    "form"
  ]

  static values = {
    fields: Array,
    operators: Array
  }

  connect() {
    this.rootCombinator = "and"
    this.loadState()
  }

  // Called before form submission to add ransack params
  // ba_spree override: 本家は送信直前に query_state から ransack の hidden input (q[...]) を
  // 組み立てて form に足していたが、これは不要なうえ有害だった。
  //
  // - 不要: コントローラの TableConcern#process_table_query_state が query_state を
  //   params[:q] にマージし直すため、q はサーバ側で再生成される
  //   (実際に /admin/orders?query_state={...} だけで絞り込みが成立することを確認済み)
  // - 有害: 「または」グループでは q[g[0][m]] という Rack が正しくパースできない名前を
  //   生成してしまい (Rack::Utils.parse_nested_query が "g[0" という壊れたキーにする)、
  //   その壊れたキーが hidden やリンクを通じて名前を変質させながら増殖していた
  //
  // 送信時には query_state さえ最新であればよい。
  // @see https://github.com/be-agile/giga-repeat/issues/1262
  submitForm(_event) {
    this.updateHiddenInput()
  }

  loadState() {
    const stateJson = this.hiddenInputTarget.value
    if (stateJson && stateJson !== "{}") {
      try {
        const state = JSON.parse(stateJson)
        this.renderState(state)
      } catch (e) {
        console.error("Failed to parse query state:", e)
      }
    }
  }

  renderState(state) {
    // ba_spree override: 再構築の前にコンテナを空にする。
    //
    // 本家はサーバ側で空の filtersContainer を描画し、connect() → loadState() →
    // renderState() が query_state を読んで行を append する(クリアしない)。
    // Spree admin は Turbo Drive のページキャッシュが有効なため、注文詳細へ遷移して
    // ブラウザ「戻る」をすると、Turbo は「JS が描画済みの行を含むスナップショット」を
    // 復元し、その後 Stimulus が再 connect して loadState() がもう一度 append する。
    // 結果、ドロワーのフィルタ行が倍増し(バッジと hidden query_state はサーバ描画のまま
    // なので開くまで気づかない)、適用すると query_state.filters が重複して増殖していく。
    //
    // renderState の冒頭でコンテナを空にすることで、再 connect / キャッシュ復元でも
    // query_state から冪等に再構築されるようにする。
    // @see https://github.com/be-agile/giga-repeat/issues/1262
    this.filtersContainerTarget.innerHTML = ""
    this.groupsContainerTarget.innerHTML = ""

    // Set root combinator
    if (state.combinator) {
      this.rootCombinator = state.combinator
      this.updateCombinatorDisplay()
    }

    // Render filters
    if (state.filters && state.filters.length > 0) {
      state.filters.forEach(filter => {
        this.addFilterWithData(filter, this.filtersContainerTarget)
      })
    }

    // Render groups
    if (state.groups && state.groups.length > 0) {
      state.groups.forEach(group => {
        this.addGroupWithData(group)
      })
    }
  }

  addFilter(event) {
    event.preventDefault()
    this.addFilterWithData({}, this.filtersContainerTarget)
    this.updateHiddenInput()
  }

  addFilterToGroup(event) {
    event.preventDefault()
    const groupEl = event.target.closest("[data-group-id]")
    const filtersContainer = groupEl.querySelector("[data-group-filters-container]")
    this.addFilterWithData({}, filtersContainer)
    this.updateHiddenInput()
  }

  addFilterWithData(filterData, container) {
    const template = this.filterTemplateTarget.content.cloneNode(true)
    const row = template.querySelector("[data-filter-id]")
    row.dataset.filterId = filterData.id || this.generateId()

    // Populate field options
    const fieldSelect = row.querySelector("[data-field-select]")
    this.fieldsValue.forEach(field => {
      const option = document.createElement("option")
      option.value = field.key
      option.textContent = field.label
      if (filterData.field === field.key) {
        option.selected = true
      }
      fieldSelect.appendChild(option)
    })

    // If we have a field selected, update operators and value
    if (filterData.field) {
      const fieldConfig = this.fieldsValue.find(f => f.key === filterData.field)
      if (fieldConfig) {
        this.updateOperatorOptions(row, fieldConfig.operators, filterData.operator)
        this.updateValueInput(row, fieldConfig, filterData.value, filterData.operator)
      }
    }

    container.appendChild(row)
  }

  addOrGroup(event) {
    event.preventDefault()
    this.addGroupWithData({ combinator: "or", filters: [], groups: [] })
    this.updateHiddenInput()
  }

  addGroupWithData(groupData) {
    const template = this.groupTemplateTarget.content.cloneNode(true)
    const group = template.querySelector("[data-group-id]")
    group.dataset.groupId = groupData.id || this.generateId()
    group.dataset.combinator = groupData.combinator || "or"

    // Update combinator label
    const label = group.querySelector("[data-group-combinator-label]")
    if (label) {
      label.textContent = (groupData.combinator || "or").toUpperCase()
    }

    // Add existing filters to the group
    if (groupData.filters && groupData.filters.length > 0) {
      const filtersContainer = group.querySelector("[data-group-filters-container]")
      groupData.filters.forEach(filter => {
        this.addFilterWithData(filter, filtersContainer)
      })
    }

    this.groupsContainerTarget.appendChild(group)
  }

  removeFilter(event) {
    event.preventDefault()
    const filterRow = event.target.closest("[data-filter-id]")
    if (filterRow) {
      filterRow.remove()
      this.updateHiddenInput()
    }
  }

  removeGroup(event) {
    event.preventDefault()
    const group = event.target.closest("[data-group-id]")
    if (group) {
      group.remove()
      this.updateHiddenInput()
    }
  }

  toggleCombinator(event) {
    event.preventDefault()
    this.rootCombinator = this.rootCombinator === "and" ? "or" : "and"
    this.updateCombinatorDisplay()
    this.updateHiddenInput()
  }

  toggleGroupCombinator(event) {
    event.preventDefault()
    const group = event.target.closest("[data-group-id]")
    const currentCombinator = group.dataset.combinator
    const newCombinator = currentCombinator === "and" ? "or" : "and"

    group.dataset.combinator = newCombinator
    const label = group.querySelector("[data-group-combinator-label]")
    if (label) {
      label.textContent = newCombinator.toUpperCase()
    }

    this.updateHiddenInput()
  }

  updateCombinatorDisplay() {
    if (this.hasCombinatorLabelTarget) {
      this.combinatorLabelTarget.textContent = this.rootCombinator.toUpperCase()
    }
  }

  onFieldChange(event) {
    const filterRow = event.target.closest("[data-filter-id]")
    const field = event.target.value
    const fieldConfig = this.fieldsValue.find(f => f.key === field)

    if (fieldConfig) {
      this.updateOperatorOptions(filterRow, fieldConfig.operators)
      const operator = filterRow.querySelector("[data-operator-select]")?.value
      this.updateValueInput(filterRow, fieldConfig, null, operator)
    }

    this.updateHiddenInput()
  }

  onOperatorChange(event) {
    const filterRow = event.target.closest("[data-filter-id]")
    const operator = event.target.value
    const noValueOperators = ["null", "not_null"]

    const valueContainer = filterRow.querySelector("[data-value-container]")
    if (noValueOperators.includes(operator)) {
      valueContainer.style.display = "none"
    } else {
      valueContainer.style.display = ""
      // Rebuild value input when switching between single/multi operators
      const field = filterRow.querySelector("[data-field-select]")?.value
      const fieldConfig = this.fieldsValue.find(f => f.key === field)
      if (fieldConfig && (fieldConfig.type === "select" || fieldConfig.type === "status")) {
        this.updateValueInput(filterRow, fieldConfig, null, operator)
      }
    }

    this.updateHiddenInput()
  }

  onValueChange() {
    this.updateHiddenInput()
  }

  updateOperatorOptions(filterRow, operators, selectedOperator = null) {
    const operatorSelect = filterRow.querySelector("[data-operator-select]")
    operatorSelect.innerHTML = ""

    // ba_spree override: 本家はラベルを JS にハードコード(英語)していたため
    // フィールド選択後に演算子セレクトが英語化していた。サーバから渡される
    // operatorsValue (operators_for_select の出力 = i18n 済みラベル) を参照する。
    const operatorLabels = {}
    this.operatorsValue.forEach(op => {
      operatorLabels[op.value] = op.label
    })

    operators.forEach(op => {
      const option = document.createElement("option")
      option.value = op
      option.textContent = operatorLabels[op] || op
      if (selectedOperator === op) {
        option.selected = true
      }
      operatorSelect.appendChild(option)
    })
  }

  updateValueInput(filterRow, fieldConfig, existingValue = null, operator = null) {
    const valueContainer = filterRow.querySelector("[data-value-container]")
    valueContainer.innerHTML = ""

    // Check if operator requires multi-select
    const isMultiOperator = ["in", "not_in"].includes(operator)

    let input
    switch (fieldConfig.type) {
      case "date":
        input = document.createElement("input")
        input.type = "date"
        input.className = "form-input text-sm"
        break
      case "datetime":
        input = document.createElement("input")
        input.type = "datetime-local"
        input.className = "form-input text-sm"
        break
      case "number":
      case "currency":
        input = document.createElement("input")
        input.type = "number"
        input.className = "form-input text-sm"
        input.step = fieldConfig.type === "currency" ? "0.01" : "1"
        break
      case "boolean":
        input = document.createElement("select")
        input.className = "form-select text-sm"
        input.innerHTML = `
          <option value="true">Yes</option>
          <option value="false">No</option>
        `
        break
      case "status":
      case "select":
        // For in/not_in operators, use multi-select with tom-select
        if (isMultiOperator) {
          const wrapper = document.createElement("div")
          wrapper.className = "w-full"
          wrapper.dataset.controller = "select"
          wrapper.dataset.selectMultipleValue = "true"

          // Build options array for tom-select
          const selectOptions = []
          if (fieldConfig.value_options) {
            fieldConfig.value_options.forEach(opt => {
              selectOptions.push({
                id: opt.value || opt,
                name: opt.label || opt
              })
            })
          }
          wrapper.dataset.selectOptionsValue = JSON.stringify(selectOptions)

          input = document.createElement("select")
          input.className = "text-sm"
          input.multiple = true
          input.dataset.selectTarget = "input"
          input.dataset.valueInput = ""

          // Restore existing values for multi-select
          if (existingValue !== null && existingValue !== undefined && Array.isArray(existingValue)) {
            const selectedIds = existingValue.map(item => {
              if (typeof item === 'object') {
                return item.id
              } else {
                return item
              }
            })
            wrapper.dataset.selectActiveOptionValue = JSON.stringify(selectedIds)
          }

          input.dataset.action = "change->query-builder#onValueChange"
          wrapper.appendChild(input)
          valueContainer.appendChild(wrapper)
          return // Early return since we already appended
        } else {
          // Single select for eq/not_eq operators
          input = document.createElement("select")
          input.className = "form-select text-sm"
          input.innerHTML = '<option value="">Select...</option>'
          if (fieldConfig.value_options) {
            fieldConfig.value_options.forEach(opt => {
              const option = document.createElement("option")
              option.value = opt.value || opt
              option.textContent = opt.label || opt
              input.appendChild(option)
            })
          }
        }
        break
      case "autocomplete":
        // Create a wrapper div with select controller
        const wrapper = document.createElement("div")
        wrapper.className = "w-full"
        wrapper.dataset.controller = "select"
        wrapper.dataset.selectMultipleValue = "true"

        if (fieldConfig.search_url) {
          wrapper.dataset.selectUrlValue = fieldConfig.search_url
          // Use remote search mode so it doesn't pre-fetch and overwrite our preloaded options
          wrapper.dataset.selectRemoteSearchValue = "true"
        }

        // Use name as value field for tags (tags_name ransack attribute expects tag names)
        const useNameAsValue = fieldConfig.key && fieldConfig.key.includes("name")
        if (useNameAsValue) {
          wrapper.dataset.selectValueFieldValue = "name"
        }

        input = document.createElement("select")
        input.className = "text-sm"
        input.multiple = true
        input.dataset.selectTarget = "input"
        input.dataset.valueInput = "" // Mark as value input for serialization

        // Restore existing values - we store as array of {id, name} objects
        // Use remoteSearchActiveOption which properly preloads options and selects them
        if (existingValue !== null && existingValue !== undefined && Array.isArray(existingValue) && existingValue.length > 0) {
          const preloadedOptions = existingValue.map(item => {
            if (typeof item === 'object') {
              return { id: useNameAsValue ? item.name : item.id, name: item.name }
            } else {
              return { id: item, name: item }
            }
          })
          wrapper.dataset.selectRemoteSearchActiveOptionValue = JSON.stringify(preloadedOptions)
        }

        // Set up change listener on select element directly
        input.dataset.action = "change->query-builder#onValueChange"

        wrapper.appendChild(input)
        valueContainer.appendChild(wrapper)

        return // Early return since we already appended
      default:
        input = document.createElement("input")
        input.type = "text"
        input.className = "form-input text-sm"
        input.placeholder = "Enter value..."
    }

    input.dataset.valueInput = ""
    input.dataset.action = "input->query-builder#onValueChange change->query-builder#onValueChange"

    if (existingValue !== null && existingValue !== undefined) {
      input.value = existingValue
    }

    valueContainer.appendChild(input)
  }

  clear(event) {
    event.preventDefault()
    this.filtersContainerTarget.innerHTML = ""
    this.groupsContainerTarget.innerHTML = ""
    this.rootCombinator = "and"
    this.updateCombinatorDisplay()
    this.updateHiddenInput()
  }

  updateHiddenInput() {
    const state = this.serializeState()
    this.hiddenInputTarget.value = JSON.stringify(state)
  }

  serializeState() {
    const filters = this.serializeFilters(this.filtersContainerTarget)
    const groups = this.serializeGroups()

    return {
      id: "root",
      combinator: this.rootCombinator,
      filters: filters,
      groups: groups
    }
  }

  serializeFilters(container) {
    const filters = []
    container.querySelectorAll(":scope > [data-filter-id]").forEach(row => {
      // Handle multi-select (tom-select) values
      const valueInput = row.querySelector("[data-value-input]")
      let value = null

      if (valueInput) {
        if (valueInput.multiple) {
          // Get all selected options for multi-select
          // Store as objects with id and name for autocomplete restoration
          value = Array.from(valueInput.selectedOptions).map(opt => ({
            id: opt.value,
            name: opt.textContent
          }))
        } else {
          value = valueInput.value
        }
      }

      const filter = {
        id: row.dataset.filterId,
        field: row.querySelector("[data-field-select]")?.value,
        operator: row.querySelector("[data-operator-select]")?.value,
        value: value
      }
      if (filter.field) {
        filters.push(filter)
      }
    })
    return filters
  }

  serializeGroups() {
    const groups = []
    this.groupsContainerTarget.querySelectorAll(":scope > [data-group-id]").forEach(groupEl => {
      const filtersContainer = groupEl.querySelector("[data-group-filters-container]")
      const group = {
        id: groupEl.dataset.groupId,
        combinator: groupEl.dataset.combinator || "or",
        filters: this.serializeFilters(filtersContainer),
        groups: []
      }
      groups.push(group)
    })
    return groups
  }

  generateId() {
    return Math.random().toString(36).substring(2, 10)
  }

}
