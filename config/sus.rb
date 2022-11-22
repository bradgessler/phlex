# frozen_string_literal: true

require "phlex"
require "bundler"

Bundler.require :test

require_relative "../fixtures/view_helper"

Zeitwerk::Loader.eager_load_all
