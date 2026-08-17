Deface::Override.new(
  virtual_path: 'spree/admin/stores/form/_checkout',
  name: 'add_special_instruction_message_settings',
  insert_after: "erb[loud]:contains('preferred_special_instructions_enabled')",
  partial: 'spree/admin/stores/special_instruction_message_settings'
)

Deface::Override.new(
  virtual_path: 'spree/checkout/_special_instructions',
  name: 'add_special_instruction_message_checkout',
  insert_after: 'h5.font-body',
  text: '
    <div id="special-instruction-message">
      <%= current_store.special_instruction_message if current_store.special_instruction_message.present? %>
    </div>
  '
)
