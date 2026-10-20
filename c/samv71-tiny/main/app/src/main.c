#include <atmel_start.h>
#include <tinymon.h>

extern void render_pins();

void process_device_input(void) {}
void normalize_data(void) {}
void convert_engineering_units(void) {}
void update_state_vector(void) {}
void render_cross_talk(void) {}

void GatherInputs(void)
{
    process_user_input();
    process_device_input();
}

void Calculate(void)
{
    normalize_data();
    convert_engineering_units();
    update_state_vector();
    build_user_messages();
}

void RenderOutput(void)
{
    render_pins();
    render_cross_talk();
    print_user_messages();
}

void WaitForCycle(void)
{
}

int main(void)
{
    system_init();
    setup_console();

    while (1)
    {
        GatherInputs();
        Calculate();
        RenderOutput();
        WaitForCycle();
    }
}
