defmodule ChangesetHelpers.Appointment do
  use Ecto.Schema

  schema "appointment" do
    field(:start_time, :time)
    field(:end_time, :time)

    field(:start_date, :date)
    field(:end_date, :date)

    field(:attendees, :integer)
    field(:max_attendees, :integer)

    field(:foo, :integer)
    field(:bar, :integer)

    field(:days_of_week, {:array, :integer})
  end
end
