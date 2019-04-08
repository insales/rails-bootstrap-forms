require_relative 'helpers/bootstrap'

module BootstrapForm
  class FormBuilder < ActionView::Helpers::FormBuilder
    include BootstrapForm::Helpers::Bootstrap

    attr_reader :layout, :label_col, :control_col, :has_error, :inline_errors, :label_errors, :acts_like_form_tag

    FIELD_HELPERS = %w{
      email_field number_field password_field phone_field
      range_field search_field telephone_field text_area text_field
      url_field}

    DATE_SELECT_HELPERS = %w{date_select time_select datetime_select}

    delegate :content_tag, :capture, :concat, to: :@template

    def initialize(object_name, object, template, options)
      @layout = options[:layout]
      @label_col = options[:label_col] || default_label_col
      @control_col = options[:control_col] || default_control_col
      @label_errors = options[:label_errors] || false
      @inline_errors = if options[:inline_errors].nil?
        @label_errors != true
      else
        options[:inline_errors] != false
      end
      @acts_like_form_tag = options[:acts_like_form_tag]

      super
    end

    FIELD_HELPERS.each do |method_name|
      alias_method "#{method_name}_without_bootstrap", method_name

      define_method(method_name) do |name, options = {}|
        form_group_builder(name, options) do
          prepend_and_append_input(options) do
            super(name, options)
          end
        end
      end
    end

    DATE_SELECT_HELPERS.each do |method_name|
      alias_method "#{method_name}_without_bootstrap", method_name

      define_method(method_name) do |*args|
        form_group_builder(*args) do
          content_tag(:div, super(*args), class: control_specific_class(method_name))
        end
      end
    end

    alias_method :file_field_without_bootstrap, :file_field

    def file_field(name, options = {})
      form_group_builder(name, options.reverse_merge(control_class: nil)) do
        super
      end
    end

    alias_method :select_without_bootstrap, :select

    def select(method, choices, options = {}, html_options = {})
      form_group_builder(method, options, html_options) do
        super
      end
    end

    alias_method :collection_select_without_bootstrap, :collection_select

    def collection_select(method, collection, value_method, text_method, options = {}, html_options = {})
      form_group_builder(method, options, html_options) do
        super
      end
    end

    alias_method :grouped_collection_select_without_bootstrap, :grouped_collection_select

    def grouped_collection_select(method, collection, group_method, group_label_method, option_key_method, option_value_method, options = {}, html_options = {})
      form_group_builder(method, options, html_options) do
        super
      end
    end

    alias_method :time_zone_select_without_bootstrap, :time_zone_select

    def time_zone_select(method, priority_zones = nil, options = {}, html_options = {})
      form_group_builder(method, options, html_options) do
        super
      end
    end

    alias_method :check_box_without_bootstrap, :check_box

    def check_box(name, options = {}, checked_value = "1", unchecked_value = "0", &block)
      options = options.symbolize_keys!

      html = super(name, options.except(:label, :help, :inline), checked_value, unchecked_value)
      label_content = block_given? ? capture(&block) : options[:label]
      html.concat(" ").concat(label_content || (object && object.class.human_attribute_name(name)) || name.to_s.humanize)

      label_name = name
      label_name = "#{name}_#{checked_value}" if options[:multiple]

      if options[:inline]
        label(label_name, html, class: "checkbox-inline")
      else
        content_tag(:div, class: "checkbox") do
          label(label_name, html)
        end
      end
    end

    alias_method :radio_button_without_bootstrap, :radio_button

    def radio_button(name, value, *args)
      options = args.extract_options!.symbolize_keys!
      args << options.except(:label, :help, :inline)

      html = super + " " + options[:label]

      if options[:inline]
        label(name, html, class: "radio-inline", value: value)
      else
        content_tag(:div, class: "radio") do
          label(name, html, value: value)
        end
      end
    end

    def collection_check_boxes(*args)
      html = inputs_collection(*args) do |name, value, options|
        options[:multiple] = true
        check_box(name, options, value, nil)
      end
      hidden_field(args.first,{value: "", multiple: true}).concat(html)
    end

    def collection_radio_buttons(*args)
      inputs_collection(*args) do |name, value, options|
        radio_button(name, value, options)
      end
    end

    def check_boxes_collection(*args)
      warn "'BootstrapForm#check_boxes_collection' is deprecated, use 'BootstrapForm#collection_check_boxes' instead"
      collection_check_boxes(*args)
    end

    def radio_buttons_collection(*args)
      warn "'BootstrapForm#radio_buttons_collection' is deprecated, use 'BootstrapForm#collection_radio_buttons' instead"
      collection_radio_buttons(*args)
    end

    def form_group(*args, &block)
      options = args.extract_options!
      name = args.first

      options[:class] = ["form-group", options[:class]].compact.join(' ')
      options[:class] << " #{error_class}" if has_error?(name)
      options[:class] << " #{feedback_class}" if options[:icon]

      content_tag(:div, options.except(:id, :label, :help, :icon, :label_col, :control_col, :layout)) do
        label = generate_label(options[:id], name, options[:label], options[:label_col], options[:layout]) if options[:label]
        control = capture(&block).to_s
        control.concat(generate_help(name, options[:help]).to_s)
        control.concat(generate_icon(options[:icon])) if options[:icon]

        if get_group_layout(options[:layout]) == :horizontal
          control_class = (options[:control_col] || control_col.clone)

          unless options[:label]
            control_offset = offset_col(/([0-9]+)$/.match(options[:label_col] || default_label_col))
            control_class.concat(" #{control_offset}")
          end
          control = content_tag(:div, control, class: control_class)
        end

        concat(label).concat(control)
      end
    end

    alias_method :fields_for_without_bootstrap, :fields_for

    def fields_for(record_name, record_object = nil, fields_options = {}, &block)
      fields_options, record_object = record_object, nil if record_object.is_a?(Hash) && record_object.extractable_options?
      fields_options[:layout] ||= options[:layout]
      fields_options[:label_col] = fields_options[:label_col].present? ? "#{fields_options[:label_col]} #{label_class}" : options[:label_col]
      fields_options[:control_col] ||= options[:control_col]
      fields_options[:inline_errors] = options[:inline_errors] if fields_options[:inline_errors].nil?
      fields_options[:label_errors] = options[:label_errors] if fields_options[:inline_errors].nil?
      super
    end

    private

    def horizontal?
      layout == :horizontal
    end

    def get_group_layout(group_layout)
      group_layout || layout
    end

    def default_label_col
      "col-sm-2"
    end

    def offset_col(offset)
      "col-sm-offset-#{offset}"
    end

    def default_control_col
      "col-sm-10"
    end

    def hide_class
      "sr-only" # still accessible for screen readers
    end

    def control_class
      "form-control"
    end

    def label_class
      "control-label"
    end

    def error_class
      "has-error"
    end

    def feedback_class
      "has-feedback"
    end

    def control_specific_class(method)
      "rails-bootstrap-forms-#{method.gsub(/_/, "-")}"
    end

    def has_error?(name)
      object.respond_to?(:errors) && !(name.nil? || object.errors[name].empty?)
    end

    def form_group_builder(method, options, html_options = nil)
      options.symbolize_keys!
      html_options.symbolize_keys! if html_options

      # Add control_class; allow it to be overridden by :control_class option
      css_options = html_options || options
      control_classes = css_options.delete(:control_class) { control_class }
      css_options[:class] = [control_classes, css_options[:class]].compact.join(" ")

      options = convert_form_tag_options(method, options) if acts_like_form_tag

      label = options.delete(:label)
      label_class = hide_class if options.delete(:hide_label)
      wrapper_class = options.delete(:wrapper_class)
      wrapper_options = options.delete(:wrapper)
      help = options.delete(:help)
      icon = options.delete(:icon)
      label_col = options.delete(:label_col)
      control_col = options.delete(:control_col)
      layout = get_group_layout(options.delete(:layout))
      form_group_options = {
        id: options[:id],
        label: {
          text: label,
          class: label_class
        },
        help: help,
        icon: icon,
        label_col: label_col,
        control_col: control_col,
        layout: layout,
        class: wrapper_class
      }

      if wrapper_options.is_a?(Hash)
        form_group_options.reverse_merge!(wrapper_options)
      end

      form_group(method, form_group_options) do
        yield
      end
    end

    def convert_form_tag_options(method, options = {})
      options[:name] ||= method
      options[:id] ||= method
      options
    end

    def generate_label(id, name, options, custom_label_col, group_layout)
      options[:for] = id if acts_like_form_tag
      classes = [options[:class], label_class]
      classes << (custom_label_col || label_col) if get_group_layout(group_layout) == :horizontal
      options[:class] = classes.compact.join(" ")

      if label_errors && has_error?(name)
        error_messages = get_error_messages(name)
        label_text = (options[:text] || name.to_s.humanize).to_s.concat(" #{error_messages}")
        label(name, label_text, options.except(:text))
      else
        label(name, options[:text], options.except(:text))
      end
    end

    def generate_help(name, help_text)
      return if help_text == false
      # TODO: split them, do not join. (?)
      errors = has_error?(name) && inline_errors ? object.errors[name].join(", ") : ''
      help_text ||= get_help_text_by_i18n_key(name)
      messages = [errors, help_text]
      messages
          .find_all(&:present?)
          .map { |m| content_tag(:span, m, class: 'help-block') }
          .reduce(&:+)
    end

    def generate_icon(icon)
      content_tag(:span, "", class: "glyphicon glyphicon-#{icon} form-control-feedback")
    end

    def get_error_messages(name)
      object.errors[name].join(", ")
    end

    def inputs_collection(name, collection, value, text, options = {}, &block)
      form_group_builder(name, options) do
        inputs = ""

        collection.each do |obj|
          input_options = options.merge(label: obj.send(text))

          if checked = input_options[:checked]
            input_options[:checked] = checked == obj.send(value)              ||
                                      checked.try(:include?, obj.send(value)) ||
                                      checked == obj                          ||
                                      checked.try(:include?, obj)
          end

          input_options.delete(:class)
          inputs << block.call(name, obj.send(value), input_options)
        end

        inputs.html_safe
      end
    end

    def get_help_text_by_i18n_key(name)
      underscored_scope = "activerecord.help.#{object.class.name.underscore}"
      downcased_scope = "activerecord.help.#{object.class.name.downcase}"
      help_text = I18n.t(name, scope: underscored_scope, default: '').presence
      help_text ||= if text = I18n.t(name, scope: downcased_scope, default: '').presence
        warn "I18n key '#{downcased_scope}.#{name}' is deprecated, use '#{underscored_scope}.#{name}' instead"
        text
      end

      help_text
    end
  end
end
