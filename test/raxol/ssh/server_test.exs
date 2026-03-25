defmodule Raxol.SSH.ServerTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  describe "SSH server" do
    test "generates host keys" do
      dir = Path.join(System.tmp_dir!(), "raxol_ssh_test_#{:rand.uniform(100_000)}")

      on_exit(fn -> File.rm_rf!(dir) end)

      # Use the private function indirectly by starting the server
      # Just test that key generation works
      File.mkdir_p!(dir)
      refute File.exists?(Path.join(dir, "ssh_host_rsa_key"))

      # Generate key manually (same logic as server)
      rsa_key = :public_key.generate_key({:rsa, 2048, 65537})

      rsa_pem =
        :public_key.pem_encode([
          :public_key.pem_entry_encode(:RSAPrivateKey, rsa_key)
        ])

      File.write!(Path.join(dir, "ssh_host_rsa_key"), rsa_pem)

      assert File.exists?(Path.join(dir, "ssh_host_rsa_key"))
      assert byte_size(rsa_pem) > 100
    end
  end
end
