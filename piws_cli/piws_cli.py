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
    def __init__(self, sensor_name, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.sensor_name = sensor_name

    def compose(self) -> ComposeResult:
        yield Grid(
            Static(f'This is a screen for .... {self.sensor_name}', id='question'),
            Button("Frank", variant="error", id="quit"),
            Button("and Beans", variant="primary", id="cancel"),
            id="dialog",
        )

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.app.pop_screen()


class Hello(Widget):
    """Display a greeting."""
    def render(self) -> RenderResult:
        return "PiWS CLI is [b]In Development[/b]!"


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
        sensor_name = event.button.id
        self.app.push_screen(SensorScreen(sensor_name=sensor_name))
        #self.app.push_screen(SensorScreen())

    def compose(self) -> ComposeResult:
        sensors = self.get_sensors()
        for sensor in sensors:
            sensor_display = sensor['sensor_display']
            sensor_name = sensor['sensor_name']
            yield Button(sensor_display, id=sensor_name)


    def get_sensors(self):
        """Queries database for sensors available.
        """
        sql_raw = """
SELECT DISTINCT 
        CASE WHEN o.node_unique_id IS NULL THEN o.sensor_name
            ELSE o.sensor_name || '-' || o.node_unique_id
            END AS sensor_name,
        CASE WHEN o.node_unique_id IS NULL THEN nm.name
            ELSE nm.name || '-' || o.node_unique_id
            END AS sensor_display
    FROM piws.vobservation o
    INNER JOIN sensor.node_model nm ON o.sensor_name = nm.column_name
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
