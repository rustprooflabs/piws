from textual.app import App, ComposeResult, RenderResult
from textual.containers import Content, Grid
from textual.screen import Screen
from textual.widget import Widget
from textual.widgets import Static, Header, Footer, Button, ListView, ListItem, Label

import psycopg_pool

#from cli import config, db
import config, db


class QuitScreen(Screen):
    def compose(self) -> ComposeResult:
        yield Grid(
            Static("Are you sure you want to quit?", id="question"),
            Button("Quit", variant="error", id="quit"),
            Button("Cancel", variant="primary", id="cancel"),
            id="dialog",
        )

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "quit":
            self.app.exit()
        else:
            self.app.pop_screen()


class SensorScreen(Screen):
    def compose(self) -> ComposeResult:
        yield Grid(
            Static('This is a screen', id='question'),
            Button("Frank", variant="error", id="quit"),
            Button("and Beans", variant="primary", id="cancel"),
            id="dialog",
        )

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.app.pop_screen()


class Hello(Widget):
    """Display a greeting."""

    def render(self) -> RenderResult:
        return "PiWS CLI [b]In Development[/b]!"


class PostgresVersion(Content):
    """Queries database to get Postgres version.
    """
    def render(self) -> RenderResult:
        sql_raw = 'SELECT version() AS pg_version;'
        try:
            data = db.get_data(sql_raw=sql_raw, single_row=True)
        except psycopg_pool.PoolTimeout:
            return 'Error connecting to Postgres'
        pg_version = data['pg_version']
        print(pg_version)
        return pg_version


class SensorList(Widget):
    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Event handler called when a button is pressed."""
        print(event.button)
        self.app.push_screen(SensorScreen())
        if event.button.id == "start":
            self.add_class("started")
        elif event.button.id == "stop":
            self.remove_class("started")

    def compose(self) -> ComposeResult:
        sensors = self.get_sensors()
        for sensor in sensors:
            sensor_name = sensor['name']
            value_type = sensor['value_type']
            sensor_item = f'{sensor_name} ({value_type})'
            yield Button(sensor_item)

    def get_sensors(self):
        """Queries database for sensors available.
        """
        sql_raw = """
SELECT nm.id, nm.name, nm.column_name ,
        vt.name AS value_type, vu.name AS value_unit
    FROM sensor.node_model nm
    INNER JOIN sensor.value_type vt ON nm.value_type_id = vt.id
    INNER JOIN sensor.value_unit vu ON nm.value_unit_id = vu.id
;
"""
        data = db.get_data(sql_raw=sql_raw)
        return data


class PiWSCLIApp(App):
    """PiWS CLI Application
    """
    CSS_PATH = "piws_cli.css"
    BINDINGS = [("q", "quit", "Quit")]

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        yield Footer()

        yield Hello()
        yield PostgresVersion()
        yield SensorList()

    def action_quit(self) -> None:
        self.push_screen(QuitScreen())


if __name__ == "__main__":
    app = PiWSCLIApp()
    app.run()
