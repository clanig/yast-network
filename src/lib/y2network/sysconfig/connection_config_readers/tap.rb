# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "y2network/sysconfig/connection_config_readers/base"

module Y2Network
  module Sysconfig
    module ConnectionConfigReaders
      # This class is able to build a ConnectionConfig::Tap object given a
      # Sysconfig::InterfaceFile object.
      class Tap < Base
      private

        # @param conn [Y2Network::ConnectionConfig::Tap]
        # @see Y2Network::Sysconfig::ConnectionConfigReaders::Base#update_connection_config
        def update_connection_config(conn)
          conn.owner = file.tunnel_set_owner
          conn.group = file.tunnel_set_group
        end
      end
    end
  end
end
