/// El texto de un campo a partir de su evento `input`.
export function inputValue(event: Event): string {
  return (event.target as HTMLInputElement).value;
}
