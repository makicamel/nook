require 'js'

module Nook
  # The side panel. Every change of a control rebuilds the model and hands it
  # to the JavaScript host, which makes the meshes and draws them.
  class Page < Funicular::Component
    def initialize_state
      { model: Nook::REGISTRY.keys.first, values: {}, colors: {}, display: 'color', upside_down: nil }
    end

    def component_mounted
      show
    end

    def component_updated
      show
    end

    def render
      @built = build
      div do
        h1 { 'nook' }
        model_field
        if @built[:error]
          p(id: 'message') { @built[:error] }
        else
          param_section(@built[:params])
          part_section(@built[:parts])
        end
        display_section
        button(disabled: !@built[:error].nil?, onclick: -> { host.download }) { 'Download 3MF' }
      end
    end

    private

    def host
      JS.global[:nookHost]
    end

    def palette
      @palette ||= JSON.parse(host[:palette])
    end

    # A model file is edited by hand, so a mistake in it or a color name
    # missing from colors.yml is shown on the page instead of the model.
    def build
      model = Nook.build(state[:model], state[:values])
      model[:parts].each do |part|
        part[:color] = state[:colors][part[:name]] || part[:color]
        entry = palette.fetch(part[:color])
        part[:hex] = entry['color']
        part[:opacity] = entry['opacity'] || 1
      end
      model
    rescue StandardError => error
      { error: "#{error.class}: #{error.message}" }
    end

    def show
      return if @built[:error]

      fit_camera = @shown_model != state[:model]
      @shown_model = state[:model]
      host.show(JSON.generate(@built), state[:display], upside_down?, fit_camera)
    end

    # Until the checkbox is used, a model that prints upside down is shown turned over.
    def upside_down?
      state[:upside_down].nil? ? @built[:printed_upside_down] : state[:upside_down]
    end

    def model_field
      label(class: 'field') do
        span { 'Model' }
        select(onchange: ->(event) { patch(model: event.target[:value], values: {}, colors: {}, upside_down: nil) }) do
          Nook::REGISTRY.keys.each do |name|
            option(value: name, selected: name == state[:model]) { name }
          end
        end
      end
    end

    def param_section(params)
      section do
        h2 { 'Dimensions' }
        params.each do |param|
          label(class: 'param', key: "#{state[:model]}/#{param[:name]}") do
            span { param[:name] }
            span(class: 'param-value') { param[:value].to_s }
            input(type: 'range', min: param[:min], max: param[:max], step: param[:step], value: param[:value],
                  oninput: ->(event) { patch(values: state[:values].merge(param[:name] => number(event.target[:value]))) })
          end
        end
      end
    end

    def part_section(parts)
      section do
        h2 { 'Parts' }
        ul(id: 'parts') do
          parts.each do |part|
            li(key: "#{state[:model]}/#{part[:name]}") do
              span(class: 'swatch', style: "background: #{part[:hex]}; opacity: #{part[:opacity]}")
              span { part[:name] }
              select(onchange: ->(event) { patch(colors: state[:colors].merge(part[:name] => event.target[:value])) }) do
                palette.each_key do |name|
                  option(value: name, selected: name == part[:color]) { name }
                end
              end
            end
          end
        end
      end
    end

    def display_section
      section do
        h2 { 'Display' }
        div(class: 'choices') do
          { 'color' => 'Color', 'mesh' => 'Mesh' }.each do |mode, text|
            label do
              input(type: 'radio', name: 'display', value: mode, checked: mode == state[:display],
                    onchange: ->(_event) { patch(display: mode) })
              span { text }
            end
          end
        end
        label(class: 'choices') do
          input(type: 'checkbox', checked: upside_down?, onchange: ->(event) { patch(upside_down: event.target[:checked]) })
          span { 'Upside down' }
        end
      end
    end

    # A range input reports "30" or "2.2". Whole numbers stay integers so that
    # the page shows 30 instead of 30.0.
    def number(text)
      value = text.to_f
      value == value.to_i ? value.to_i : value
    end
  end
end

Funicular.start(Nook::Page, container: 'panel')
