# frozen_string_literal: true

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.0")
	using Phlex::Overrides::Symbol::Name
end

# Extending this module provides the {register_element} macro for registering your own custom elements. It's already extended by {HTML} and {SVG}.
# @example
# 	module MyCustomElements
# 		extend Phlex::Elements
#
# 		register_element :trix_editor
# 	end
#
# 	class MyComponent < Phlex::HTML
# 		include MyCustomElements
#
# 		def template
# 			trix_editor
# 		end
# 	end
module Phlex::Elements
	# @api private
	class VoidElement
		attr_reader :name
		attr_accessor :attributes

		def initialize(name, **attributes)
			@name = name
			@attributes = attributes
		end

		def tag(**attributes)
			@attributes = attributes
		end

		def deconstruct
			[@name, @attributes]
		end

		def deconstruct_keys(*)
			Hash[*deconstruct]
		end

		def ===(target)
			case target
			when Symbol
				@name === target
			else
				self === target
			end
		end
	end

	# @api private
	class Element < VoidElement
		attr_accessor :content

		def initialize(name, **attributes, &content)
			super(name, **attributes)
			@content = content
		end

		def tag(**attributes, &content)
			super(**attributes)
			@content = content
		end
	end

	# @api private
	def registered_elements
		@registered_elements ||= Concurrent::Map.new
	end

	# Register a custom element. This macro defines an element method for the current class and descendents only. There is no global element registry.
	# @param method_name [Symbol]
	# @param tag [String] the name of the tag, otherwise this will be the method name with underscores replaced with dashes.
	# @return [Symbol] the name of the method created
	# @note The methods defined by this macro depend on other methods from {SGML} so they should always be mixed into an {HTML} or {SVG} component.
	# @example Register the custom element `<trix-editor>`
	# 	register_element :trix_editor
	def register_element(method_name, tag: nil)
		tag ||= method_name.name.tr("_", "-")

		class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
			# frozen_string_literal: true

			def #{method_name}(object = nil, **attributes, &block)
				target = @_context.target

				if object.respond_to? :phlex_html
					element = Element.new(:#{tag}, **attributes, &block)
					object.phlex_html element
					attributes = element.attributes

					if content = element.content&.call
						block = case content
						when Phlex::HTML
							Proc.new { render content }
						else
							Proc.new { content }
						end
					end
				end

				if attributes.length > 0 # with attributes
					if block # with content block
						target << "<#{tag}" << (Phlex::ATTRIBUTE_CACHE[respond_to?(:process_attributes) ? (attributes.hash + self.class.hash) : attributes.hash] || __attributes__(**attributes)) << ">"
						yield_content(&block)
						target << "</#{tag}>"
					else # without content block
						target << "<#{tag}" << (Phlex::ATTRIBUTE_CACHE[respond_to?(:process_attributes) ? (attributes.hash + self.class.hash) : attributes.hash] || __attributes__(**attributes)) << "></#{tag}>"
					end
				else # without attributes
					if block # with content block
						target << "<#{tag}>"
						yield_content(&block)
						target << "</#{tag}>"
					else # without content block
						target << "<#{tag}></#{tag}>"
					end
				end

				#{'flush' if tag == 'head'}

				nil
			end

			alias_method :_#{method_name}, :#{method_name}
		RUBY

		registered_elements[method_name] = tag

		method_name
	end

	# @api private
	def register_void_element(method_name, tag: nil)
		tag ||= method_name.name.tr("_", "-")

		class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
			# frozen_string_literal: true

			def #{method_name}(object = nil, **attributes)
				target = @_context.target

				if object.respond_to? :phlex_html
					element = VoidElement.new(:#{tag}, **attributes)
					object.phlex_html element
					attributes = element.attributes
				end

				if attributes.length > 0 # with attributes
					target << "<#{tag}" << (Phlex::ATTRIBUTE_CACHE[respond_to?(:process_attributes) ? (attributes.hash + self.class.hash) : attributes.hash] || __attributes__(**attributes)) << ">"
				else # without attributes
					target << "<#{tag}>"
				end

				nil
			end

			alias_method :_#{method_name}, :#{method_name}
		RUBY

		registered_elements[method_name] = tag

		method_name
	end
end
