import base64
import importlib.util
import json
import os
from pathlib import Path
import threading
import unittest
import urllib.error
import urllib.request
from unittest.mock import patch

os.environ['SIMULATOR_ACCESS_TOKEN'] = 'test-only-' + 'x'*40
spec = importlib.util.spec_from_file_location('bridge', Path(__file__).with_name('server.py'))
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class BridgeSecurityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = bridge.ThreadingHTTPServer(('127.0.0.1', 0), bridge.Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.url = 'http://127.0.0.1:' + str(cls.server.server_port)

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def request(self, path, body=None, token=None):
        headers = {} if token is None else {'Authorization': 'Bearer '+token}
        request = urllib.request.Request(self.url+path, headers=headers, data=None if body is None else json.dumps(body).encode())
        try:
            with urllib.request.urlopen(request) as response:
                return response.status, response.read()
        except urllib.error.HTTPError as error:
            return error.code, error.read()

    def test_frames_and_commands_require_secret(self):
        with patch.object(bridge, 'driver') as driver:
            self.assertEqual(self.request('/frame')[0], 401)
            self.assertEqual(self.request('/command', {'kind':'restart'}, 'wrong')[0], 401)
            driver.assert_not_called()

    def test_authenticated_frame(self):
        with patch.object(bridge, 'driver', return_value=base64.b64encode(b'png').decode()):
            self.assertEqual(self.request('/frame', token=bridge.TOKEN), (200, b'png'))

    def test_no_arbitrary_commands_or_files(self):
        with patch.object(bridge, 'driver') as driver:
            self.assertEqual(self.request('/command', {'kind':'shell','text':'whoami'}, bridge.TOKEN)[0], 400)
            self.assertEqual(self.request('/../../server.py', token=bridge.TOKEN)[0], 404)
            self.assertEqual(self.request('/command', {'kind':'swipe','direction':'invalid'}, bridge.TOKEN)[0], 400)
            driver.assert_not_called()

    def test_expired_session_rejects_commands(self):
        with patch.object(bridge, 'EXPIRES', 0), patch.object(bridge, 'driver') as driver:
            self.assertEqual(self.request('/command', {'kind':'restart'}, bridge.TOKEN)[0], 410)
            driver.assert_not_called()


if __name__ == '__main__':
    unittest.main()
