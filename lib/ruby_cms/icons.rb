# frozen_string_literal: true

module RubyCms
  module Icons
    # Named Heroicon SVG path fragments (outline style, 24x24 viewBox).
    # Use symbol keys with nav_register / register_page: `icon: :home`
    # Raw SVG strings are still accepted for custom icons.
    REGISTRY = {
      home: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
            'd="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3' \
            'm-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path>',

      pencil_square: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                     'd="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 ' \
                     '0 012.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path>',

      document_duplicate: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                          'd="M8 7v8a2 2 0 002 2h6M8 7V5a2 2 0 012-2h4.586a1 1 0 01.707.293l4.414 4.414' \
                          'a1 1 0 01.293.707V15a2 2 0 01-2 2h-2M8 7H6a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 ' \
                          '0 002-2v-2"></path>',

      chart_bar: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                 'd="M3 3v18h18"></path>' \
                 '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                 'd="M7 13l3-3 3 2 4-5"></path>',

      shield_check: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                    'd="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01' \
                    '-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 ' \
                    '9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"></path>',

      exclamation_triangle: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                            'd="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 ' \
                            '4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path>',

      user_group: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                  'd="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 ' \
                  '00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"></path>',

      cog_6_tooth: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                   'd="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 ' \
                   '1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 ' \
                   '1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 ' \
                   '6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 ' \
                   '0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 ' \
                   '1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 ' \
                   '6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 ' \
                   '1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 ' \
                   '1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z"></path>' \
                   '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>',

      # Extra icons for host-app admin pages
      archive_box: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                   'd="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4"></path>',

      folder: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
              'd="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"></path>',

      bell: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
            'd="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"></path>',

      clock: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
             'd="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>',

      tag: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
           'd="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"></path>',

      cube: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
            'd="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"></path>',

      envelope: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                'd="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>',

      wrench: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
              'd="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path>' \
              '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>',

      globe: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
             'd="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"></path>',

      photograph: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                  'd="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>',

      list_bullet: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                   'd="M4 6h16M4 10h16M4 14h16M4 18h16"></path>',

      plus_circle: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                   'd="M12 9v3m0 0v3m0-3h3m-3 0H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z"></path>',

      trash: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
             'd="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>',

      eye: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
           'd="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>' \
           '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
           'd="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>',

      lock_closed: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                   'd="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>',

      currency_dollar: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                       'd="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>'
    }.freeze

    def self.resolve(name_or_svg)
      return name_or_svg if name_or_svg.kind_of?(String) && name_or_svg.include?("<")
      return nil if name_or_svg.nil?

      REGISTRY.fetch(name_or_svg.to_sym) do
        raise ArgumentError, "Unknown icon: #{name_or_svg}. Available: #{REGISTRY.keys.join(', ')}"
      end
    end

    def self.available
      REGISTRY.keys
    end
  end
end
