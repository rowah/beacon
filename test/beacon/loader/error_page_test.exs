defmodule Beacon.Loader.ErrorPageTest do
  use Beacon.Web.ConnCase, async: false
  use Beacon.Test, site: :my_site

  defp build_conn(conn) do
    conn
    |> Plug.Conn.assign(:beacon, Beacon.Web.BeaconAssigns.new(default_site()))
    |> Plug.Conn.put_private(:phoenix_router, Beacon.BeaconTest.Router)
  end

  setup %{conn: conn} do
    :ok = Beacon.Loader.populate_default_layouts(default_site())
    :ok = Beacon.Loader.populate_default_error_pages(default_site())
    error_module = Beacon.Loader.load_error_page_module(default_site())

    [conn: build_conn(conn), error_module: error_module]
  end

  test "root layout", %{conn: conn, error_module: error_module} do
    expected =
      ~S"""
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta name="csrf-token" content=.* />
          <title>Error</title>
          <link rel="stylesheet" href=/__beacon_assets__/css-.* />
          <script defer src=/__beacon_assets__/js-.*>
          </script>
        </head>
        <body>
          #inner_content#
        </body>
      </html>
      """
      |> Regex.compile!()

    {:safe, html} = error_module.root_layout(%{conn: conn, inner_content: "#inner_content#"})
    assert IO.iodata_to_binary(html) =~ expected
  end

  test "default layouts", %{error_module: error_module} do
    assert error_module.layout(404, %{inner_content: "Not Found"}) == {:safe, ["Not Found"]}
    assert error_module.layout(500, %{inner_content: "Internal Server Error"}) == {:safe, ["Internal Server Error"]}
  end

  test "custom layout" do
    layout = beacon_published_layout_fixture(template: "#custom_layout#<%= @inner_content %>")
    error_page = beacon_error_page_fixture(layout: layout, template: "error_501", status: 501)
    error_module = Beacon.Loader.fetch_error_page_module(default_site())

    assert error_module.layout(501, %{inner_content: error_page.template}) == {:safe, ["#custom_layout#", "error_501"]}
  end

  test "default error pages", %{conn: conn, error_module: error_module} do
    expected =
      ~S"""
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta name="csrf-token" content=.* />
          <title>Error</title>
          <link rel="stylesheet" href=/__beacon_assets__/css-.* />
          <script defer src=/__beacon_assets__/js-.*>
          </script>
        </head>
        <body>
          Not Found
        </body>
      </html>
      """
      |> Regex.compile!()

    {:safe, html} = error_module.render(conn, 404)
    assert IO.iodata_to_binary(html) =~ expected

    expected =
      ~S"""
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta name="csrf-token" content=.* />
          <title>Error</title>
          <link rel="stylesheet" href=/__beacon_assets__/css-.* />
          <script defer src=/__beacon_assets__/js-.*>
          </script>
        </head>
        <body>
          Internal Server Error
        </body>
      </html>
      """
      |> Regex.compile!()

    {:safe, html} = error_module.render(conn, 500)
    assert IO.iodata_to_binary(html) =~ expected
  end

  test "custom error page", %{conn: conn} do
    layout = beacon_published_layout_fixture(template: "#custom_layout#<%= @inner_content %>")
    _error_page = beacon_error_page_fixture(layout: layout, template: ~s|<span class="text-red-500">error_501</span>|, status: 501)
    error_module = Beacon.Loader.fetch_error_page_module(default_site())

    expected =
      ~S"""
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta name="csrf-token" content=.* />
          <title>Error</title>
          <link rel="stylesheet" href=/__beacon_assets__/css-.* />
          <script defer src=/__beacon_assets__/js-.*>
          </script>
        </head>
        <body>
          #custom_layout#<span class="text-red-500">error_501</span>
        </body>
      </html>
      """
      |> Regex.compile!()

    {:safe, html} = error_module.render(conn, 501)

    assert IO.iodata_to_binary(html) =~ expected
  end
end
