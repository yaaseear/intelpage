exports.handler = async (event) => {
  const { text } = JSON.parse(event.body);
  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': process.env.ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01'
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1000,
      system: 'Return ONLY a raw JSON array of exactly 5 objects. Each has "key" (uppercase 1-2 word label) and "text" (one sentence, max 110 chars). No markdown.',
      messages: [{ role: 'user', content: 'Summarise:\n\n' + text }]
    })
  });
  const data = await response.json();
  const clean = data.content[0].text.replace(/```json|```/g,'').trim();
  return {
    statusCode: 200,
    headers: { 'Access-Control-Allow-Origin': '*' },
    body: clean
  };
};