/**
 * Validate standard UUID format (v4 / general 8-4-4-4-12 hex string)
 * @param {string} str
 * @returns {boolean}
 */
export const isValidUuid = (str) => {
  if (typeof str !== 'string') return false;
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(str);
};

export default {
  isValidUuid,
};
