defmodule RaxolPlaygroundWeb.SkillController do
  @moduledoc """
  Serves the Raxol agent onboarding skill file at /skill.md.
  """
  use RaxolPlaygroundWeb, :controller

  @skill_path Path.join(:code.priv_dir(:raxol_playground), "static/skill.md")

  def show(conn, _params) do
    content =
      case File.read(@skill_path) do
        {:ok, data} -> data
        {:error, _} -> "# Raxol\n\nSkill file not found."
      end

    conn
    |> put_resp_content_type("text/markdown")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, content)
  end
end
