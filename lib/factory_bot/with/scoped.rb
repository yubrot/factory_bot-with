# frozen_string_literal: true

module FactoryBot
  class With
    # An internal class to implement implicit context scope.
    class Scoped
      class << self
        # @!visibility private
        # @return [Array<Array(AssocInfo, Object)>, nil]
        def ancestors = Thread.current[:factory_bot_with_scoped_ancestors]

        # @param ancestors [Array<Array(AssocInfo, Object)>]
        def with_ancestors(ancestors, &)
          tmp_ancestors = self.ancestors
          Thread.current[:factory_bot_with_scoped_ancestors] = [*ancestors, *tmp_ancestors || []]
          yield
        ensure
          Thread.current[:factory_bot_with_scoped_ancestors] = tmp_ancestors
        end

        # @!visibility private
        # @param objects [{Symbol => Object}]
        def with_objects(objects, &) = with_ancestors(objects.map { [AssocInfo.get(_1), _2] }, &)

        # @!visibility private
        def block(&block)
          params = block.parameters
          if params.any? { %i[req opt rest].include?(_1[0]) }
            ->(objects) { with_objects(objects) { block.call(*objects.values) } }
          elsif params.any? { %i[keyreq key keyrest].include?(_1[0]) }
            ->(objects) { with_objects(objects) { block.call(**objects) } }
          else
            ->(objects) { with_objects(objects, &block) }
          end
        end
      end
    end
  end
end
