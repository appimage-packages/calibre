#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Scarlett Clark <sgclark@kde.org>
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require 'docker'
require 'logger'
require 'logger/colors'

class CI
    class Build
        def initialize()
            @image = ''
            @c = ''
            @binds = ''
        end
    end
    def init_logging
        @log = Logger.new(STDERR)

        raise 'Could not initialize logger' if @log.nil?

        Thread.new do
            # :nocov:
            Docker::Event.stream { |event| @log.debug event }
            # :nocov:
        end
    end
    attr_accessor :run
    attr_accessor :cmd

    Docker.options[:read_timeout] = 1 * 60 * 60 # 1 hour
    Docker.options[:write_timeout] = 1 * 60 * 60 # 1 hour

   def create_container
        init_logging
        @c = Docker::Container.create(
            'Image' => 'sgclark/trusty-minimal',
            'Cmd' => @cmd,
            'Volumes' => {
              '/in' => {},
              '/out' => {}
            }
        )
        p @c.info
        @log.info 'creating debug thread'
        Thread.new do
            @c.attach do |_stream, chunk|
                puts chunk
                STDOUT.flush
            end
        end
        @c.start('Binds' => ["/home/jenkins/workspace/appimage-calibre/:/in",
                             "/home/jenkins/workspace/appimage-calibre/out:/out"])
        ret = @c.wait
        status_code = ret.fetch('StatusCode', 1)
        raise "Bad return #{ret}" if status_code != 0
        @c.stop!
    end
end
