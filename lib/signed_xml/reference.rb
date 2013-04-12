module SignedXml
  class Reference
    include Transformable

    attr_reader :here, :start

    def initialize(here)
      @here = here

      uri = here['URI']
      case uri
      when nil, ""
        @start = here.document.root
      when /^#/
        id = uri.split('#').last
        raise ArgumentError, "XPointer expressions like #{id} are not yet supported" if id =~ /^xpointer/
        # TODO: handle ID attrs with names other than 'ID'
        @start = here.document.at_xpath("//*[@ID='#{id}']")
        raise ArgumentError, "no match found for ID #{id}" if @start.nil?
      else
        raise ArgumentError, "unsupported Reference URI #{uri}"
      end

      @transforms = init_transforms
    end

    def is_verified?
      apply_transforms.chomp == digest_value
    end

    private

    def init_transforms
      transforms = []

      here.xpath('.//ds:Transform', ds: XMLDSIG_NS).each do |transform_node|
        method = transform_node['Algorithm']
        case method
        when "http://www.w3.org/2000/09/xmldsig#enveloped-signature"
          transforms << EnvelopedSignatureTransform.new
        when %r{^http://.*c14n}
          transforms << C14NTransform.new(method)
        else
          raise ArgumentError, "unknown transform method #{method}"
        end
      end

      # If no explicit c14n transform is specified, make sure we do one before digesting.
      transforms << C14NTransform.new unless transforms.last.is_a? C14NTransform

      digest_method = here.at_xpath('//ds:DigestMethod/@Algorithm', ds: XMLDSIG_NS).value.strip
      transforms << DigestTransform.new(digest_method)

      transforms << Base64Transform.new
    end

    def digest_value
      @digest_value ||= here.at_xpath('ds:DigestValue', ds: XMLDSIG_NS).text.strip
    end
  end
end
